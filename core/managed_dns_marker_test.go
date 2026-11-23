package core

import "testing"

func TestManagedDNSMarkerIsIgnoredByMihomoParser(t *testing.T) {
	raw, err := unmarshalRawConfig([]byte("dns:\n  enable: true\n  x-zolnit-managed-doh: 1\n  nameserver: [https://dns.example/dns-query]\n"))
	if err != nil {
		t.Fatal(err)
	}
	if !raw.DNS.Enable || len(raw.DNS.NameServer) != 1 {
		t.Fatal("marked DNS did not reach parser")
	}
}
