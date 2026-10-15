package tun

import "encoding/json"

type Options struct {
	RecvMsgX               bool   `json:"recvMsgX"`
	SendMsgX               bool   `json:"sendMsgX"`
	Stack                  string `json:"stack"`
	Address                string `json:"address"`
	DNS                    string `json:"dns"`
	MTU                    uint32 `json:"mtu"`
	DisableICMPForwarding  bool   `json:"disableIcmpForwarding"`
	EndpointIndependentNAT bool   `json:"endpointIndependentNat"`
	CongestionController   string `json:"congestionController"`
}

func (options *Options) UnmarshalJSON(data []byte) error {
	type wire Options
	var decoded struct {
		wire
		CongestionController   *string `json:"congestion-controller"`
		DisableICMPForwarding  *bool   `json:"disable-icmp-forwarding"`
		EndpointIndependentNAT *bool   `json:"endpoint-independent-nat"`
	}
	if err := json.Unmarshal(data, &decoded); err != nil {
		return err
	}
	*options = Options(decoded.wire)
	if decoded.CongestionController != nil {
		options.CongestionController = *decoded.CongestionController
	}
	if decoded.DisableICMPForwarding != nil {
		options.DisableICMPForwarding = *decoded.DisableICMPForwarding
	}
	if decoded.EndpointIndependentNAT != nil {
		options.EndpointIndependentNAT = *decoded.EndpointIndependentNAT
	}
	return nil
}
