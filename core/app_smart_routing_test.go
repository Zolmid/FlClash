package core

import (
	"net/netip"
	"testing"

	"github.com/metacubex/mihomo/component/process"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/rules"
)

type appRoutingRuleSet struct {
	C.Rule
	name string
}

func (r appRoutingRuleSet) RuleType() C.RuleType { return C.RuleSet }
func (r appRoutingRuleSet) Payload() string      { return r.name }

func appRoutingFixture(t *testing.T) *config.Config {
	t.Helper()
	parse := func(kind, payload, target string) C.Rule {
		t.Helper()
		r, err := rules.ParseRule(kind, payload, target, nil, nil)
		if err != nil {
			t.Fatal(err)
		}
		return r
	}
	raw := config.DefaultRawConfig()
	raw.FindProcessMode = process.FindProcessOff
	cfg, err := config.ParseRawConfig(raw)
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"proxy", "domestic", "fallback", "ai"} {
		cfg.Proxies[name] = cfg.Proxies["DIRECT"]
	}
	cfg.Rules = []C.Rule{
		parse("DOMAIN-SUFFIX", "lan", "DIRECT"),
		parse("DOMAIN-SUFFIX", "zolmid.com", "DIRECT"),
		parse("DOMAIN-SUFFIX", "googleapis.cn", "proxy"),
		parse("DOMAIN", "ai.example", "ai"),
		appRoutingRuleSet{parse("DOMAIN", "foreign.example", "proxy"), "foreign"},
		appRoutingRuleSet{parse("DOMAIN-SUFFIX", "qq.com", "domestic"), "mainland"},
		appRoutingRuleSet{parse("IP-CIDR", "198.51.100.0/24", "domestic"), "cn-ip"},
		parse("MATCH", "", "fallback"),
	}
	return cfg
}

func appRoutingTestLease() *RoutingLeaseSpec {
	return &RoutingLeaseSpec{AccountID: "account", BundleID: "bundle", ConnectionDigest: "digest"}
}

func TestAppSmartRoutingPrecedence(t *testing.T) {
	cfg := appRoutingFixture(t)
	if !installSmartAppRouting(cfg, appRoutingTestLease(), "android") || len(cfg.Rules) != 10 {
		t.Fatal("official Android rule table was not extended")
	}
	if cfg.General.FindProcessMode != process.FindProcessStrict {
		t.Fatal("process lookup must be lazy")
	}
	for _, test := range []struct {
		name, host, ip, owner, outbound string
		match                           C.RuleType
		lookup                          bool
	}{
		{"LAN before App", "printer.lan", "", "org.telegram.messenger", "DIRECT", C.DomainSuffix, false},
		{"control before App", "link.zolmid.com", "", "org.telegram.messenger", "DIRECT", C.DomainSuffix, false},
		{"service before App", "ai.example", "", "org.telegram.messenger", "ai", C.Domain, false},
		{"Google Play before App", "services.googleapis.cn", "", "com.tencent.mm", "proxy", C.DomainSuffix, false},
		{"known domain before proxy App", "im.qq.com", "", "org.telegram.messenger", "domestic", C.RuleSet, true},
		{"domestic App scoped to publisher", "img.qpic.cn", "", "com.tencent.mm", "domestic", C.AND, true},
		{"same domain without App identity", "img.qpic.cn", "", "", "fallback", C.MATCH, true},
		{"domestic App with unknown destination", "unknown.test.cn", "", "com.tencent.mobileqq", "fallback", C.MATCH, true},
		{"proxy App with literal China IP", "", "198.51.100.10", "org.telegram.messenger", "proxy", C.AND, true},
		{"China IP with unknown App", "", "198.51.100.10", "org.telegram.messenger.copy", "domestic", C.RuleSet, true},
		{"Signal proxy on unknown domain", "unknown.example", "", "org.thoughtcrime.securesms", "proxy", C.AND, true},
	} {
		t.Run(test.name, func(t *testing.T) {
			metadata := C.Metadata{Host: test.host, NetWork: C.TCP}
			if test.ip != "" {
				metadata.DstIP = netip.MustParseAddr(test.ip)
			}
			lookedUp := false
			helper := C.RuleMatchHelper{FindProcess: func() {
				lookedUp = true
				metadata.Process = test.owner
			}}
			for _, rule := range cfg.Rules {
				if match, outbound := rule.Match(&metadata, helper); match {
					if outbound != test.outbound || rule.RuleType() != test.match || lookedUp != test.lookup {
						t.Fatalf("route=%s rule=%s lookedUp=%v", outbound, rule.RuleType(), lookedUp)
					}
					return
				}
			}
			t.Fatal("missing final rule")
		})
	}
}

func TestAppSmartRoutingDesktopPaths(t *testing.T) {
	for _, test := range []struct{ platform, valid, invalid string }{
		{"darwin", "/Applications/Signal.app/Contents/MacOS/Signal", "/tmp/Signal.app/Contents/MacOS/Signal"},
		{"windows", `C:\Users\Example\AppData\Roaming\Telegram Desktop\Telegram.exe`, `C:\Users\Example\Temp\Telegram.exe`},
		{"linux", "/usr/bin/telegram-desktop", "/tmp/telegram-desktop"},
	} {
		t.Run(test.platform, func(t *testing.T) {
			cfg := appRoutingFixture(t)
			if !installSmartAppRouting(cfg, appRoutingTestLease(), test.platform) {
				t.Fatal("desktop rule table was not extended")
			}
			app := cfg.Rules[len(cfg.Rules)-3]
			metadata := C.Metadata{NetWork: C.TCP, ProcessPath: test.valid}
			if match, target := app.Match(&metadata, C.RuleMatchHelper{}); !match || target != "proxy" {
				t.Fatal("known installation path did not use proxy")
			}
			metadata.NetWork = C.UDP
			if match, _ := app.Match(&metadata, C.RuleMatchHelper{}); match {
				t.Fatal("desktop UDP used a potentially ambiguous process path")
			}
			metadata.NetWork = C.TCP
			metadata.ProcessPath = test.invalid
			if match, _ := app.Match(&metadata, C.RuleMatchHelper{}); match {
				t.Fatal("unrelated path was treated as the official install")
			}
		})
	}
}

func TestAppSmartRoutingOnlyManagedKnownPlatforms(t *testing.T) {
	for _, test := range []struct {
		platform string
		lease    *RoutingLeaseSpec
	}{
		{"ios", appRoutingTestLease()},
		{"android", nil},
		{"linux", &RoutingLeaseSpec{AccountID: "account", BundleID: "bundle"}},
	} {
		cfg := appRoutingFixture(t)
		if installSmartAppRouting(cfg, test.lease, test.platform) || len(cfg.Rules) != 8 || cfg.General.FindProcessMode != process.FindProcessOff {
			t.Fatalf("unmanaged/unsupported setup changed on %s", test.platform)
		}
	}
	cfg := appRoutingFixture(t)
	cfg.Rules = cfg.Rules[:4]
	if installSmartAppRouting(cfg, appRoutingTestLease(), "android") || len(cfg.Rules) != 4 {
		t.Fatal("unknown rule layout admits a precedence change")
	}
}
