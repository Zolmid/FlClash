package core

import (
	"core/clientbundle"
	"encoding/json"
	"os"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/tunnel"
	"go.yaml.in/yaml/v3"
)

func TestClientBundleReturnRouteProducerAliasesReachCoreWithoutChangingAI(t *testing.T) {
	body, err := os.ReadFile("../packages/zolnit_client/test/fixtures/ui-groups-bundle-producer-v1.json")
	if err != nil {
		t.Fatal(err)
	}
	envelope, _ := json.Marshal(map[string]json.RawMessage{"data": body})
	prepared, code := clientbundle.Prepare(envelope, "account-1", "{}", time.Unix(1001, 0))
	if code != "" {
		t.Fatal(code)
	}
	var data struct {
		Routing struct {
			Groups []struct {
				ID      string `json:"id"`
				Group   string `json:"group"`
				Options []struct {
					ID     string `json:"id"`
					Target string `json:"target"`
				} `json:"options"`
			} `json:"ui_groups"`
		} `json:"routing"`
	}
	if err := json.Unmarshal(body, &data); err != nil {
		t.Fatal(err)
	}
	if len(data.Routing.Groups) != 1 || data.Routing.Groups[0].ID != "return_route" {
		t.Fatal("missing producer role")
	}
	role := data.Routing.Groups[0]
	if len(role.Options) != 3 {
		t.Fatal("incomplete producer options")
	}
	var doc struct {
		Groups []struct {
			Name    string   `yaml:"name"`
			Type    string   `yaml:"type"`
			Members []string `yaml:"proxies"`
		} `yaml:"proxy-groups"`
	}
	if err := yaml.Unmarshal(prepared.Document, &doc); err != nil {
		t.Fatal(err)
	}
	proxies := map[string]constant.Proxy{"REJECT": rejectNode(), "DIRECT": directNode("DIRECT")}
	for _, outbound := range prepared.Bundle.Outbounds {
		proxies[outbound.Name] = networkNode(t, outbound.Name)
	}
	for _, group := range doc.Groups {
		if group.Type != "url-test" && group.Type != "fallback" {
			continue
		}
		members := []constant.Proxy{}
		for _, name := range group.Members {
			if node := proxies[name]; node != nil {
				members = append(members, node)
			}
		}
		hc := provider.NewHealthCheck(members, "", 0, 0, true, nil)
		pd, err := provider.NewCompatibleProvider(group.Name, members, hc)
		if err != nil {
			t.Fatal(err)
		}
		var actual outboundgroup.ProxyGroup
		if group.Type == "fallback" {
			actual, err = outboundgroup.NewFallback(outboundgroup.GroupCommonOption{Name: group.Name},
				outboundgroup.FallbackOption{}, proxies["REJECT"], []cp.ProxyProvider{pd})
		} else {
			actual, err = outboundgroup.NewURLTest(outboundgroup.GroupCommonOption{Name: group.Name},
				outboundgroup.URLTestOption{}, proxies["REJECT"], []cp.ProxyProvider{pd})
		}
		if err != nil {
			t.Fatal(err)
		}
		proxies[group.Name] = adapter.NewProxy(actual)
	}
	members := []constant.Proxy{}
	for _, option := range role.Options {
		if proxies[option.Target] == nil {
			t.Fatalf("producer target missing: %s", option.ID)
		}
		if option.Target == "DIRECT" || option.Target == "REJECT" {
			t.Fatal("reserved return target")
		}
		members = append(members, proxies[option.Target])
	}
	selector := selectorOver(t, role.Group, members...)
	proxies[role.Group] = selector
	ai := selectorOver(t, "zn.service.ai", proxies["DIRECT"], proxies["REJECT"])
	proxies["zn.service.ai"] = ai
	tunnel.UpdateProxies(proxies, nil)
	t.Cleanup(func() { settleMessageBatcher(); tunnel.UpdateProxies(nil, nil) })
	for _, option := range role.Options {
		result := handleChangeProxy(&ChangeProxyParams{GroupName: role.Group, ProxyName: option.Target})
		if result.Message != "" || selector.Adapter().(pickableGroup).Now() != option.Target {
			t.Fatalf("Core rejected %s: %s", option.ID, result.Message)
		}
		if ai.Adapter().(pickableGroup).Now() != "DIRECT" {
			t.Fatal("return choice altered independent AI selector")
		}
	}
}
