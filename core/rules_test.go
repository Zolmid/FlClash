package core

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	R "github.com/metacubex/mihomo/rules"
	RW "github.com/metacubex/mihomo/rules/wrapper"
	"github.com/metacubex/mihomo/tunnel"
)

func parseTestRule(t *testing.T, tp, payload, target string, wrap bool) constant.Rule {
	t.Helper()
	rule, err := R.ParseRule(tp, payload, target, nil, nil)
	if err != nil {
		t.Fatalf("parse %s,%s: %v", tp, payload, err)
	}
	if wrap {
		return RW.NewRuleWrapper(rule)
	}
	return rule
}

func TestNewCoreRulesReportsWrapperStatistics(t *testing.T) {
	suffix := parseTestRule(t, "DOMAIN-SUFFIX", "example.com", "DIRECT", true)
	ruleSet := parseTestRule(t, "RULE-SET", "ads", "REJECT", true)
	match := parseTestRule(t, "MATCH", "", "Proxy", false)

	suffix.Match(&constant.Metadata{Host: "www.example.com"}, constant.RuleMatchHelper{})
	suffix.Match(&constant.Metadata{Host: "other.org"}, constant.RuleMatchHelper{})
	suffix.(constant.RuleWrapper).SetDisabled(true)

	rules := newCoreRules(
		[]constant.Rule{suffix, ruleSet, match},
		map[string]cp.RuleProvider{"ads": &fakeRuleProvider{name: "ads", vehicle: cp.HTTP}},
	)

	if len(rules) != 3 {
		t.Fatalf("rules = %+v", rules)
	}
	first := rules[0]
	if first.Index != 0 || first.Type != "DomainSuffix" || first.Payload != "example.com" || first.Proxy != "DIRECT" {
		t.Fatalf("first = %+v", first)
	}
	if !first.Disabled || first.HitCount != 1 || first.MissCount != 1 || first.HitAt == nil || first.MissAt == nil {
		t.Fatalf("first statistics = %+v", first)
	}
	if first.Size != -1 {
		t.Fatalf("first size = %d", first.Size)
	}
	if rules[1].Size != 0 || rules[1].HitAt != nil || rules[1].MissAt != nil {
		t.Fatalf("rule set = %+v", rules[1])
	}
	if rules[2].Type != "Match" || rules[2].Proxy != "Proxy" || rules[2].Disabled {
		t.Fatalf("match = %+v", rules[2])
	}
}

func TestNewCoreRulesOmitsTimesThatNeverHappened(t *testing.T) {
	rule := parseTestRule(t, "DOMAIN", "example.com", "DIRECT", true)

	data, err := json.Marshal(newCoreRules([]constant.Rule{rule}, nil))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(data), "hitAt") || strings.Contains(string(data), "missAt") {
		t.Fatalf("encoded = %s", data)
	}
}

func TestSetRuleDisabledRequiresTheSameRule(t *testing.T) {
	suffix := parseTestRule(t, "DOMAIN-SUFFIX", "example.com", "DIRECT", true)
	match := parseTestRule(t, "MATCH", "", "Proxy", false)
	rules := []constant.Rule{suffix, match}

	cases := []struct {
		name   string
		params SetRuleDisabledParams
	}{
		{"out of range", SetRuleDisabledParams{Index: 2, Type: "Match", Disabled: true}},
		{"negative", SetRuleDisabledParams{Index: -1, Disabled: true}},
		{"payload changed", SetRuleDisabledParams{Index: 0, Type: "DomainSuffix", Payload: "example.org", Disabled: true}},
		{"type changed", SetRuleDisabledParams{Index: 0, Type: "Domain", Payload: "example.com", Disabled: true}},
		{"not wrapped", SetRuleDisabledParams{Index: 1, Type: "Match", Disabled: true}},
	}
	for _, tc := range cases {
		if setRuleDisabled(rules, &tc.params) {
			t.Errorf("%s: applied", tc.name)
		}
	}
	if suffix.(constant.RuleWrapper).IsDisabled() {
		t.Fatal("a rejected request disabled the rule")
	}

	if !setRuleDisabled(rules, &SetRuleDisabledParams{Index: 0, Type: "DomainSuffix", Payload: "example.com", Disabled: true}) {
		t.Fatal("matching request was rejected")
	}
	if !suffix.(constant.RuleWrapper).IsDisabled() {
		t.Fatal("rule was not disabled")
	}
}

func TestRuleMutationRejectsAnIdenticalRuleFromAnotherConfig(t *testing.T) {
	for _, tp := range []string{"DOMAIN", "MATCH"} {
		t.Run(tp, func(t *testing.T) {
			payload := ""
			if tp == "DOMAIN" {
				payload = "example.com"
			}
			first := parseTestRule(t, tp, payload, "DIRECT", true)
			second := parseTestRule(t, tp, payload, "DIRECT", true)
			withRuntimeRules(t, []constant.Rule{first})
			snapshot := handleGetRules()
			params := SetRuleDisabledParams{
				Generation: snapshot.Generation,
				Index:      0,
				Type:       snapshot.Rules[0].Type,
				Payload:    payload,
				Disabled:   true,
			}
			if !handleSetRuleDisabled(&params) || !first.(constant.RuleWrapper).IsDisabled() {
				t.Fatal("same-config request was rejected")
			}
			if handleGetRules().Generation != snapshot.Generation {
				t.Fatal("a runtime switch changed the configuration identity")
			}

			configMu.Lock()
			tunnel.UpdateRules([]constant.Rule{second}, nil, nil)
			configMu.Unlock()
			if handleSetRuleDisabled(&params) || second.(constant.RuleWrapper).IsDisabled() {
				t.Fatal("old-config request disabled the identical replacement rule")
			}
			replacement := handleGetRules()
			if replacement.Generation == snapshot.Generation {
				t.Fatal("replacement retained the old configuration identity")
			}
			params.Generation = replacement.Generation
			if !handleSetRuleDisabled(&params) || !second.(constant.RuleWrapper).IsDisabled() {
				t.Fatal("replacement's own request was rejected")
			}
		})
	}
}

func TestRuleMutationRejectsATokenFromAnotherCoreInstance(t *testing.T) {
	rule := parseTestRule(t, "MATCH", "", "DIRECT", true)
	withRuntimeRules(t, []constant.Rule{rule})
	old := handleGetRules()
	configMu.Lock()
	rulesGeneration = ""
	rulesSnapshot = nil
	configMu.Unlock()
	current := handleGetRules()
	if old.Generation == "" || old.Generation == current.Generation {
		t.Fatal("independent Core instances shared a rules token")
	}
	params := SetRuleDisabledParams{
		Generation: old.Generation,
		Index:      0,
		Type:       "Match",
		Disabled:   true,
	}
	if handleSetRuleDisabled(&params) || rule.(constant.RuleWrapper).IsDisabled() {
		t.Fatal("a token from the previous NE/Core instance remained valid")
	}
	params.Generation = current.Generation
	if !handleSetRuleDisabled(&params) {
		t.Fatal("the current Core instance rejected its own token")
	}
}

func withRuntimeRules(t *testing.T, rules []constant.Rule) {
	t.Helper()
	configMu.Lock()
	previous, providers := tunnel.Rules(), tunnel.RuleProvidersSnapshot()
	generation, snapshot := rulesGeneration, rulesSnapshot
	tunnel.UpdateRules(rules, nil, nil)
	configMu.Unlock()
	t.Cleanup(func() {
		configMu.Lock()
		defer configMu.Unlock()
		tunnel.UpdateRules(previous, nil, providers)
		rulesGeneration, rulesSnapshot = generation, snapshot
	})
}
