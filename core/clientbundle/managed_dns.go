package clientbundle

import (
	"net"
	"net/netip"
	"net/url"
	"regexp"
	"strconv"
	"strings"
)

var dnsLabel = regexp.MustCompile(`^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$`)

func privatePolicyDomain(raw string) string {
	name := strings.ToLower(strings.TrimSpace(raw))
	name = strings.TrimPrefix(name, "+.")
	name = strings.TrimSuffix(name, ".")
	if len(name) > 253 || (!strings.Contains(name, ".") && name != "lan" && name != "local" && name != "internal") {
		return ""
	}
	for _, label := range strings.Split(name, ".") {
		if !dnsLabel.MatchString(label) {
			return ""
		}
	}
	return name
}

func privatePolicyServer(raw, domain string) bool {
	raw = strings.TrimSpace(raw)
	if raw == "system" || raw == "system://" {
		for _, suffix := range []string{".lan", ".local", ".internal", ".home.arpa"} {
			if domain == strings.TrimPrefix(suffix, ".") || strings.HasSuffix(domain, suffix) {
				return true
			}
		}
		return false
	}
	ip, err := netip.ParseAddr(raw)
	if err != nil {
		host, port, splitErr := net.SplitHostPort(raw)
		number, numberErr := strconv.Atoi(port)
		if splitErr != nil || numberErr != nil || number < 1 || number > 65535 {
			return false
		}
		ip, err = netip.ParseAddr(host)
	}
	if err != nil {
		return false
	}
	if ip.Is4() {
		b := ip.As4()
		return b[0] == 10 || b[0] == 172 && b[1] >= 16 && b[1] <= 31 || b[0] == 192 && b[1] == 168
	}
	return ip.Is6() && ip.As16()[0]&0xfe == 0xfc
}

func dnsStrings(value any) ([]string, bool) {
	if s, ok := value.(string); ok {
		return []string{s}, true
	}
	list, ok := value.([]any)
	if !ok || len(list) == 0 {
		return nil, false
	}
	result := make([]string, 0, len(list))
	for _, item := range list {
		s, ok := item.(string)
		if !ok {
			return nil, false
		}
		result = append(result, s)
	}
	return result, true
}

func encryptedResolver(value string) bool {
	u, err := url.Parse(strings.TrimSpace(value))
	return err == nil && (u.Scheme == "https" || u.Scheme == "tls") && u.Hostname() != "" && u.User == nil
}

func validResolvers(value any, domain string) bool {
	servers, ok := dnsStrings(value)
	if !ok {
		return false
	}
	for _, server := range servers {
		if !encryptedResolver(server) && (domain == "" || !privatePolicyServer(server, domain)) {
			return false
		}
	}
	return true
}

func mergeManagedDNS(config map[string]any, overlay any) string {
	source, ok := config["dns"].(map[string]any)
	if !ok || source["enable"] == false {
		return "invalid_managed_dns"
	}
	if _, ok := source["nameserver"].([]any); !ok || !validResolvers(source["nameserver"], "") {
		return "invalid_managed_dns"
	}
	for _, key := range []string{"fallback", "default-nameserver", "direct-nameserver", "proxy-server-nameserver"} {
		value, present := source[key]
		if !present || value == nil {
			continue
		}
		if list, ok := value.([]any); ok && len(list) == 0 {
			continue
		}
		if !validResolvers(value, "") {
			return "invalid_managed_dns"
		}
	}
	source["enable"] = true
	rawPolicy, present := source["nameserver-policy"]
	policy := map[string]any{}
	if present {
		var valid bool
		policy, valid = rawPolicy.(map[string]any)
		if !valid {
			return "invalid_managed_dns"
		}
	}
	for _, key := range []string{"nameserver-policy", "proxy-server-nameserver-policy"} {
		value, exists := source[key]
		if !exists || value == nil {
			continue
		}
		policies, ok := value.(map[string]any)
		if !ok {
			return "invalid_managed_dns"
		}
		for domain, servers := range policies {
			if !validResolvers(servers, privatePolicyDomain(domain)) {
				return "invalid_managed_dns"
			}
		}
	}
	preferences, _ := overlay.(map[string]any)
	if preferences["listen"] == "" {
		source["listen"] = ""
	}
	additions, _ := preferences["nameserver-policy"].(map[string]any)
	for key, value := range additions {
		if _, exists := policy[key]; exists {
			continue
		}
		domain := privatePolicyDomain(key)
		servers, valid := dnsStrings(value)
		if domain == "" || !valid {
			continue
		}
		for _, server := range servers {
			if !privatePolicyServer(server, domain) {
				valid = false
				break
			}
		}
		if !valid {
			continue
		}
		for existing := range policy {
			other := privatePolicyDomain(existing)
			if other == "" || domain == other || strings.HasSuffix(domain, "."+other) || strings.HasSuffix(other, "."+domain) {
				return "managed_dns_policy_conflict"
			}
		}
		policy[key] = value
	}
	if len(policy) > 0 || present {
		source["nameserver-policy"] = policy
	}
	return ""
}
