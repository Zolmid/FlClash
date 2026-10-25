package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"net"
	"sync"

	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/resolver"
	C "github.com/metacubex/mihomo/constant"
	MT "github.com/metacubex/tls"
)

var runtimeNetworkMu sync.Mutex

func applyRuntimeNetwork(ipv6 bool) func() {
	runtimeNetworkMu.Lock()
	previous := resolver.DisableIPv6
	resolver.DisableIPv6 = !ipv6
	return func() {
		resolver.DisableIPv6 = previous
		runtimeNetworkMu.Unlock()
	}
}

func proxyNetworkDialer(mapping map[string]any, through C.Dialer) C.Dialer {
	var opts []dialer.Option
	version := C.DualStack
	if value, ok := mapping["ip-version"].(string); ok {
		_ = version.UnmarshalText([]byte(value))
	}
	if through != nil && version == C.DualStack {
		return through
	}
	switch version {
	case C.IPv4Only:
		opts = append(opts, dialer.WithOnlySingleStack(true))
	case C.IPv6Only:
		opts = append(opts, dialer.WithOnlySingleStack(false))
	case C.IPv4Prefer:
		opts = append(opts, dialer.WithPreferIPv4())
	case C.IPv6Prefer:
		opts = append(opts, dialer.WithPreferIPv6())
	}
	if through != nil {
		opts = append(opts, dialer.WithNetDialer(through))
	}
	return dialer.NewDialer(opts...)
}

type networkPhaseError struct {
	stage string
	cause error
}

func (e *networkPhaseError) Error() string { return e.stage }
func (e *networkPhaseError) Unwrap() error { return e.cause }

func classifyNetworkFailure(err error, tlsStage string) string {
	var phase *networkPhaseError
	if errors.As(err, &phase) {
		return phase.stage
	}
	var timeout net.Error
	if errors.Is(err, context.DeadlineExceeded) || (errors.As(err, &timeout) && timeout.Timeout()) {
		return "timeout"
	}
	var dnsError *net.DNSError
	if errors.As(err, &dnsError) || errors.Is(err, resolver.ErrIPNotFound) || errors.Is(err, resolver.ErrIPVersion) || errors.Is(err, resolver.ErrIPv6Disabled) {
		return "hostname_lookup"
	}
	var cert *tls.CertificateVerificationError
	var coreCert *MT.CertificateVerificationError
	var invalidCert x509.CertificateInvalidError
	var unknownAuthority x509.UnknownAuthorityError
	var hostname x509.HostnameError
	var record tls.RecordHeaderError
	var coreRecord MT.RecordHeaderError
	if errors.As(err, &cert) || errors.As(err, &coreCert) || errors.As(err, &invalidCert) || errors.As(err, &unknownAuthority) || errors.As(err, &hostname) || errors.As(err, &record) || errors.As(err, &coreRecord) {
		return tlsStage
	}
	var op *net.OpError
	if errors.As(err, &op) && op.Op == "dial" {
		return "dial"
	}
	return "unknown"
}

func setFailureStage(stages []*string, err error) {
	for _, stage := range stages {
		if stage != nil {
			*stage = classifyNetworkFailure(err, "target_tls")
		}
	}
}
