package clientbundle

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"time"

	"go.yaml.in/yaml/v3"
)

type ServiceSpec struct {
	GroupName, AutomaticGroup, ManualGroup string
	AllowedProxies                         []string
}

type Prepared struct {
	MetadataDigest string
	Document       []byte
	Bundle         *Bundle
	Digest         string
	Services       []ServiceSpec
}

func Prepare(body []byte, account, overlay string, now time.Time) (*Prepared, string) {
	validated, code := Parse(body, account, now)
	if code != "" {
		return nil, code
	}
	var root struct {
		Data struct {
			Routing struct {
				Services []struct {
					ID        string   `json:"id"`
					Kind      string   `json:"kind"`
					Providers []string `json:"providers"`
					Countries []string `json:"allowed_countries"`
				} `json:"services"`
				Nodes []struct {
					ID       string   `json:"id"`
					Enabled  bool     `json:"enabled"`
					Services []string `json:"services"`
					Revision string   `json:"revision"`
					Egress   struct {
						Country  string `json:"country"`
						Source   string `json:"source"`
						Verified bool   `json:"verified"`
					} `json:"final_egress"`
				} `json:"nodes"`
			} `json:"routing"`
		} `json:"data"`
	}
	if json.Unmarshal(body, &root) != nil {
		return nil, "invalid_bundle_metadata"
	}
	var config, preferences map[string]any
	if yaml.Unmarshal([]byte(validated.Bundle.Connection.Document), &config) != nil ||
		(overlay != "" && yaml.Unmarshal([]byte(overlay), &preferences) != nil) {
		return nil, "invalid_connection_yaml"
	}
	allNames := make([]string, 0, len(validated.Bundle.Outbounds)+1)
	for _, outbound := range validated.Bundle.Outbounds {
		allNames = append(allNames, outbound.Name)
	}
	allNames = append(allNames, "DIRECT")
	groups := config["proxy-groups"].([]any)
	managed := map[string]map[string]any{}
	services := make([]ServiceSpec, 0, len(root.Data.Routing.Services))
	for index, service := range root.Data.Routing.Services {
		if !contains([]string{"ai", "media", "general", "domestic"}, service.Kind) ||
			len(service.Providers) == 0 || len(service.Countries) == 0 {
			return nil, "invalid_bundle_metadata"
		}
		original := validated.Bundle.Routing.Services[index]
		candidates := []string{}
		for _, node := range root.Data.Routing.Nodes {
			if !node.Enabled || !node.Egress.Verified ||
				!contains([]string{"operator_verified", "egress_probe"}, node.Egress.Source) ||
				!contains(node.Services, service.ID) || !contains(service.Countries, node.Egress.Country) ||
				len(node.Egress.Country) != 2 || node.Revision == "" ||
				(service.Kind == "ai" && node.Egress.Country == "HK") {
				continue
			}
			if name := validated.Names[node.ID]; name != "" {
				candidates = append(candidates, name)
			}
		}
		managed[original.Group] = map[string]any{"name": original.Group, "type": "select",
			"proxies": []string{original.Auto, original.Manual, "DIRECT"}}
		managed[original.Auto] = map[string]any{"name": original.Auto, "type": "select",
			"proxies": append([]string{"REJECT"}, candidates...)}
		managed[original.Manual] = map[string]any{"name": original.Manual, "type": "select",
			"proxies": allNames}
		services = append(services, ServiceSpec{GroupName: original.Group,
			AutomaticGroup: original.Auto, ManualGroup: original.Manual, AllowedProxies: candidates})
	}
	nextGroups := make([]any, 0, len(groups)+2*len(services))
	for _, value := range groups {
		group := value.(map[string]any)
		name := group["name"].(string)
		if replacement := managed[name]; replacement != nil {
			nextGroups = append(nextGroups, replacement)
			delete(managed, name)
		} else {
			nextGroups = append(nextGroups, group)
		}
	}
	for _, service := range services {
		nextGroups = append(nextGroups, managed[service.AutomaticGroup], managed[service.ManualGroup])
	}
	config["proxy-groups"] = nextGroups
	for key, value := range preferences {
		switch key {
		case "proxies", "proxy-groups", "sub-rules":
		case "rules":
			additional, ok := value.([]any)
			server, serverOK := config["rules"].([]any)
			if !ok || !serverOK {
				return nil, "invalid_connection_overlay"
			}
			config[key] = append(additional, server...)
		default:
			config[key] = value
		}
	}
	for _, key := range []string{"x-zolnit-routing", "zolnit-routing"} {
		delete(config, key)
	}
	document, err := yaml.Marshal(config)
	if err != nil {
		return nil, "invalid_connection_yaml"
	}
	hash := sha256.Sum256(append(append([]byte{}, body...), []byte(overlay)...))
	var raw struct {
		Data struct {
			Routing map[string]any `json:"routing"`
		} `json:"data"`
	}
	_ = json.Unmarshal(body, &raw)
	metadata, _ := json.Marshal(raw.Data.Routing)
	metadataHash := sha256.Sum256(metadata)
	return &Prepared{Document: document, Bundle: validated.Bundle, Digest: hex.EncodeToString(hash[:]),
		MetadataDigest: hex.EncodeToString(metadataHash[:]),
		Services:       services}, ""
}

func contains(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}
