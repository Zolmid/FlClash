package core

import (
	"strings"

	"github.com/metacubex/mihomo/component/process"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/rules"
	"github.com/metacubex/mihomo/rules/wrapper"
)

type smartAppPolicy struct {
	mainland []string
	proxy    []string
}

func knownSmartApps(platform string) smartAppPolicy {
	switch platform {
	case "android":
		return smartAppPolicy{
			mainland: []string{"PROCESS-NAME,com.tencent.mm", "PROCESS-NAME,com.tencent.mobileqq"},
			proxy:    []string{"PROCESS-NAME,org.telegram.messenger", "PROCESS-NAME,org.thoughtcrime.securesms"},
		}
	case "darwin":
		return smartAppPolicy{
			mainland: []string{"PROCESS-PATH,/Applications/QQ.app/Contents/MacOS/QQ"},
			proxy: []string{
				"PROCESS-PATH,/Applications/Telegram.app/Contents/MacOS/Telegram",
				"PROCESS-PATH,/Applications/Signal.app/Contents/MacOS/Signal",
			},
		}
	case "windows":
		return smartAppPolicy{proxy: []string{
			`PROCESS-PATH-REGEX,^[a-z]:\\Users\\[^\\]+\\AppData\\Roaming\\Telegram Desktop\\Telegram\.exe$`,
			`PROCESS-PATH-REGEX,^[a-z]:\\Users\\[^\\]+\\AppData\\Local\\Programs\\signal-desktop\\Signal\.exe$`,
		}}
	case "linux":
		return smartAppPolicy{proxy: []string{
			"PROCESS-PATH,/usr/bin/telegram-desktop",
			"PROCESS-PATH,/opt/Signal/signal-desktop",
		}}
	default:
		return smartAppPolicy{}
	}
}

func appRuleAny(predicates ...string) string {
	return "OR,((" + strings.Join(predicates, "),(") + "))"
}

func newAppRule(platform, action string, predicates ...string) (C.Rule, error) {
	if platform != "android" {
		predicates = append([]string{"NETWORK,tcp"}, predicates...)
	}
	payload := "((" + strings.Join(predicates, "),(") + "))"
	rule, err := rules.ParseRule("AND", payload, action, nil, nil)
	if err != nil {
		return nil, err
	}
	return wrapper.NewRuleWrapper(rule), nil
}

func installSmartAppRouting(cfg *config.Config, lease *RoutingLeaseSpec, platform string) bool {
	if lease == nil || lease.AccountID == "" || lease.BundleID == "" || lease.ConnectionDigest == "" {
		return false
	}
	policy := knownSmartApps(platform)
	end := len(cfg.Rules)
	if len(policy.proxy) == 0 || end < 4 {
		return false
	}
	foreign, mainland, chinaIP, fallback := cfg.Rules[end-4], cfg.Rules[end-3], cfg.Rules[end-2], cfg.Rules[end-1]
	if foreign.RuleType() != C.RuleSet || foreign.Payload() != "foreign" ||
		mainland.RuleType() != C.RuleSet || mainland.Payload() != "mainland" ||
		chinaIP.RuleType() != C.RuleSet || chinaIP.Payload() != "cn-ip" ||
		fallback.RuleType() != C.MATCH ||
		foreign.Adapter() == mainland.Adapter() || cfg.Proxies[foreign.Adapter()] == nil || cfg.Proxies[mainland.Adapter()] == nil {
		return false
	}

	proxy, err := newAppRule(platform, foreign.Adapter(), appRuleAny(policy.proxy...))
	if err != nil {
		return false
	}
	var domestic C.Rule
	if len(policy.mainland) > 0 {
		domestic, err = newAppRule(platform, mainland.Adapter(),
			appRuleAny("DOMAIN-SUFFIX,qq.com", "DOMAIN-SUFFIX,qpic.cn"),
			appRuleAny(policy.mainland...))
		if err != nil {
			return false
		}
	}
	updated := make([]C.Rule, 0, end+2)
	updated = append(updated, cfg.Rules[:end-3]...)
	if domestic != nil {
		updated = append(updated, domestic)
	}
	cfg.Rules = append(updated, mainland, proxy, chinaIP, fallback)
	if cfg.General.FindProcessMode == process.FindProcessOff {
		cfg.General.FindProcessMode = process.FindProcessStrict
	}
	return true
}
