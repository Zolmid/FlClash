package tun

import (
	"encoding/json"
	"testing"
)

func TestOptionsAcceptBothMobileProtocols(t *testing.T) {
	for _, data := range []string{
		`{"mtu":1400,"congestion-controller":"bbr","disable-icmp-forwarding":true,"endpoint-independent-nat":true}`,
		`{"mtu":1400,"congestionController":"bbr","disableIcmpForwarding":true,"endpointIndependentNat":true}`,
	} {
		var options Options
		if err := json.Unmarshal([]byte(data), &options); err != nil {
			t.Fatal(err)
		}
		if options.MTU != 1400 || options.CongestionController != "bbr" || !options.DisableICMPForwarding || !options.EndpointIndependentNAT {
			t.Fatalf("options = %+v", options)
		}
	}
}

func TestOptionsKeepExplicitFalseAndLegacyKeys(t *testing.T) {
	options := Options{RecvMsgX: true, SendMsgX: true, EndpointIndependentNAT: true}
	data := []byte(`{"recvMsgX":false,"sendMsgX":false,"endpointIndependentNat":true,"endpoint-independent-nat":false}`)
	if err := json.Unmarshal(data, &options); err != nil {
		t.Fatal(err)
	}
	if options.RecvMsgX || options.SendMsgX || options.EndpointIndependentNAT {
		t.Fatalf("explicit false was lost: %+v", options)
	}
}
