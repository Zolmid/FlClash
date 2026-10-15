//go:build ios

package tun

import (
	"encoding/json"
	"net"
	"net/netip"
	"strings"
	"syscall"

	"github.com/metacubex/mihomo/constant"
	LC "github.com/metacubex/mihomo/listener/config"
	"github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
)

func Start(fd int, stack, address, dns, rawOptions string) *sing_tun.Listener {
	if fd <= 0 {
		return nil
	}
	var settings Options
	if err := json.Unmarshal([]byte(rawOptions), &settings); err != nil {
		log.Errorln("TUN: %v", err)
		return nil
	}

	var prefix4, prefix6 []netip.Prefix
	for _, value := range strings.Split(address, ",") {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		prefix, err := netip.ParsePrefix(value)
		if err != nil {
			log.Errorln("TUN: %v", err)
			return nil
		}
		if prefix.Addr().Is4() {
			prefix4 = append(prefix4, prefix)
		} else {
			prefix6 = append(prefix6, prefix)
		}
	}

	var dnsHijack []string
	for _, value := range strings.Split(dns, ",") {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		hijack := net.JoinHostPort(value, "53")
		if _, err := netip.ParseAddrPort(hijack); err != nil {
			log.Errorln("TUN: %v", err)
			return nil
		}
		dnsHijack = append(dnsHijack, hijack)
	}
	tunStack, ok := constant.StackTypeMapping[strings.ToLower(stack)]
	if !ok {
		tunStack = constant.TunMips
	}
	tunFd, err := syscall.Dup(fd)
	if err != nil {
		log.Errorln("TUN: dup fd: %v", err)
		return nil
	}
	options := LC.Tun{
		Enable:                 true,
		Device:                 "FlClash",
		Stack:                  tunStack,
		RecvMsgX:               settings.RecvMsgX,
		SendMsgX:               settings.SendMsgX,
		DNSHijack:              dnsHijack,
		Inet4Address:           prefix4,
		Inet6Address:           prefix6,
		MTU:                    settings.MTU,
		FileDescriptor:         tunFd,
		DisableICMPForwarding:  settings.DisableICMPForwarding,
		EndpointIndependentNat: settings.EndpointIndependentNAT,
		CongestionController:   settings.CongestionController,
		LoopbackAddress:        []netip.Addr{netip.MustParseAddr("10.7.0.1")},
	}
	// NetworkExtension owns fd. A Darwin configure failure leaves the duplicate
	// with us; later errors close it through sing-tun's Listener.Close.
	listener, err := sing_tun.New(options, tunnel.Tunnel)
	if err != nil {
		if strings.HasPrefix(err.Error(), "configure tun interface:") {
			_ = syscall.Close(tunFd)
		}
		log.Errorln("TUN: %v", err)
		return nil
	}
	return listener
}
