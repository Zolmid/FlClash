package core

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/base64"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/metacubex/mihomo/component/ca"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/dns"
)

const (
	firstPartyHTTPMaxRequest  = 1 << 20
	firstPartyHTTPMaxResponse = 8 << 20
	firstPartyHTTPMaxTimeout  = 25 * time.Second
	firstPartyHTTPConcurrency = 16
	firstPartyHTTPMaxEnvelope = (firstPartyHTTPMaxRequest+2)/3*4 + 32768
)

var (
	firstPartyHTTPIDs  = regexp.MustCompile(`^[A-Za-z0-9_-]{1,128}$`)
	firstPartyHTTPPath = regexp.MustCompile(`^/api/v1/[A-Za-z0-9_/-]+$`)
	firstPartyHTTP     = newFirstPartyHTTPService(newFirstPartyHTTPTransport)
)

var firstPartyHTTPHeaders = map[string]struct{}{
	"accept": {}, "authorization": {}, "content-language": {},
	"content-type": {}, "user-agent": {}, "x-zolnit-core-version": {},
	"x-zolnit-distribution": {}, "x-zolnit-platform": {},
}

type firstPartyHTTPKey struct{ client, request string }

type firstPartyHTTPService struct {
	mu        sync.Mutex
	pending   map[firstPartyHTTPKey]context.CancelFunc
	cancelled map[firstPartyHTTPKey]time.Time
	transport func() *http.Transport
}

func newFirstPartyHTTPService(transport func() *http.Transport) *firstPartyHTTPService {
	return &firstPartyHTTPService{pending: make(map[firstPartyHTTPKey]context.CancelFunc),
		cancelled: make(map[firstPartyHTTPKey]time.Time), transport: transport}
}

func firstPartyHTTPHandler(call *MethodCall) (any, error) {
	var params FirstPartyHTTPParams
	if len(call.Arguments) > firstPartyHTTPMaxEnvelope || call.decodeArguments(&params) != nil {
		return nil, firstPartyHTTPError("invalid_request")
	}
	return handleFirstPartyHTTP(params)
}

func cancelFirstPartyHTTPHandler(call *MethodCall) (any, error) {
	var params FirstPartyHTTPCancelParams
	if len(call.Arguments) > 512 || call.decodeArguments(&params) != nil ||
		!firstPartyHTTPIDs.MatchString(params.ClientID) || !firstPartyHTTPIDs.MatchString(params.RequestID) {
		return nil, firstPartyHTTPError("invalid_request")
	}
	return handleCancelFirstPartyHTTP(params), nil
}

func handleFirstPartyHTTP(params FirstPartyHTTPParams) (*FirstPartyHTTPResult, error) {
	return firstPartyHTTP.send(params)
}

func (s *firstPartyHTTPService) send(params FirstPartyHTTPParams) (result *FirstPartyHTTPResult, err error) {
	defer func() {
		if recover() != nil {
			result, err = nil, firstPartyHTTPError("internal_error")
		}
	}()
	if params.Timeout <= 0 || params.Timeout > firstPartyHTTPMaxTimeout.Milliseconds() ||
		!firstPartyHTTPIDs.MatchString(params.ClientID) || !firstPartyHTTPIDs.MatchString(params.RequestID) {
		return nil, firstPartyHTTPError("invalid_request")
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(params.Timeout)*time.Millisecond)
	defer cancel()
	key := firstPartyHTTPKey{params.ClientID, params.RequestID}
	if err := s.admit(key, cancel); err != nil {
		return nil, err
	}
	defer func() { s.mu.Lock(); delete(s.pending, key); s.mu.Unlock() }()
	parsed, parseErr := url.Parse(params.URL)
	if parseErr != nil || parsed.Scheme != "https" || parsed.Host != "link.zolmid.com" ||
		parsed.User != nil || parsed.Fragment != "" || parsed.RawPath != "" ||
		!firstPartyHTTPPath.MatchString(parsed.Path) || strings.Contains(parsed.Path, "//") ||
		len(params.URL) > 8192 || (params.Method != http.MethodGet && params.Method != http.MethodPost) ||
		!validFirstPartyHTTPHeaders(params.Headers) {
		return nil, firstPartyHTTPError("invalid_request")
	}
	if len(params.Body) > base64.StdEncoding.EncodedLen(firstPartyHTTPMaxRequest) {
		return nil, firstPartyHTTPError("request_too_large")
	}
	body, decodeErr := base64.StdEncoding.Strict().DecodeString(params.Body)
	if decodeErr != nil {
		return nil, firstPartyHTTPError("invalid_request")
	}
	if len(body) > firstPartyHTTPMaxRequest {
		return nil, firstPartyHTTPError("request_too_large")
	}
	if params.Method == http.MethodGet && len(body) != 0 {
		return nil, firstPartyHTTPError("invalid_request")
	}
	request, requestErr := http.NewRequestWithContext(ctx, params.Method, parsed.String(), bytes.NewReader(body))
	if requestErr != nil {
		return nil, firstPartyHTTPError("invalid_request")
	}
	request.GetBody = nil
	for name, value := range params.Headers {
		request.Header.Set(name, value)
	}
	transport := s.transport()
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, CheckRedirect: func(*http.Request, []*http.Request) error {
		return http.ErrUseLastResponse
	}}
	response, responseErr := client.Do(request)
	if responseErr != nil {
		return nil, firstPartyHTTPNetworkError(ctx, responseErr)
	}
	defer response.Body.Close()
	if response.ContentLength > firstPartyHTTPMaxResponse {
		return nil, firstPartyHTTPError("response_too_large")
	}
	payload, readErr := io.ReadAll(io.LimitReader(response.Body, firstPartyHTTPMaxResponse+1))
	if readErr != nil {
		return nil, firstPartyHTTPNetworkError(ctx, readErr)
	}
	if len(payload) > firstPartyHTTPMaxResponse {
		return nil, firstPartyHTTPError("response_too_large")
	}
	headers := map[string]string{}
	for _, name := range []string{"Content-Type", "Retry-After"} {
		if value := response.Header.Get(name); validFirstPartyHTTPHeaderValue(value) {
			headers[name] = value
		}
	}
	return &FirstPartyHTTPResult{Status: response.StatusCode, Headers: headers,
		Body: base64.StdEncoding.EncodeToString(payload)}, nil
}

func (s *firstPartyHTTPService) admit(key firstPartyHTTPKey, cancel context.CancelFunc) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.pruneCancellations()
	if _, ok := s.cancelled[key]; ok {
		return firstPartyHTTPError("cancelled")
	}
	if _, ok := s.pending[key]; ok {
		return firstPartyHTTPError("invalid_request")
	}
	if len(s.pending) >= firstPartyHTTPConcurrency {
		return firstPartyHTTPError("busy")
	}
	s.pending[key] = cancel
	return nil
}

func handleCancelFirstPartyHTTP(params FirstPartyHTTPCancelParams) bool {
	return firstPartyHTTP.cancel(params)
}

func (s *firstPartyHTTPService) cancel(params FirstPartyHTTPCancelParams) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	key := firstPartyHTTPKey{params.ClientID, params.RequestID}
	if cancel, ok := s.pending[key]; ok {
		cancel()
		return true
	}
	s.pruneCancellations()
	// Dispatch runs on goroutines, so cancellation may arrive before admission.
	if len(s.cancelled) >= 128 {
		return false
	}
	s.cancelled[key] = time.Now().Add(firstPartyHTTPMaxTimeout)
	return true
}

func (s *firstPartyHTTPService) pruneCancellations() {
	for key, expiry := range s.cancelled {
		if time.Now().After(expiry) {
			delete(s.cancelled, key)
		}
	}
}

func newFirstPartyHTTPTransport() *http.Transport {
	// DirectHostResolver can inherit nameserver-policy/respect-rules. Bootstrap
	// only this origin with the app's literal default resolvers, outside that policy.
	r := dns.NewResolver(dns.Config{Main: []dns.NameServer{
		{Net: "udp", Addr: "223.5.5.5:53"}, {Net: "udp", Addr: "1.0.0.1:53"},
	}, IPv6: true, CacheMaxSize: 16})
	return firstPartyHTTPTransport(func(ctx context.Context, network, address string) (net.Conn, error) {
		return dialer.DialContext(ctx, network, address, dialer.WithResolver(r.Resolver))
	})
}

func firstPartyHTTPTransport(dial func(context.Context, string, string) (net.Conn, error)) *http.Transport {
	roots, err := ca.GetTLSConfig(ca.Option{ZeroTrust: true})
	tlsConfig := &tls.Config{MinVersion: tls.VersionTLS12}
	if err == nil && roots != nil {
		tlsConfig.RootCAs = roots.RootCAs
	}
	return &http.Transport{
		DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
			host, port, err := net.SplitHostPort(address)
			if err != nil || host != "link.zolmid.com" || port != "443" {
				return nil, firstPartyHTTPError("invalid_request")
			}
			return dial(ctx, network, address)
		},
		TLSClientConfig:     tlsConfig,
		TLSHandshakeTimeout: 10 * time.Second, DisableKeepAlives: true,
		MaxResponseHeaderBytes: 16384,
	}
}

func validFirstPartyHTTPHeaderValue(value string) bool {
	if len(value) > 8192 {
		return false
	}
	for _, char := range value {
		if char < 32 || char > 126 {
			return false
		}
	}
	return true
}

func validFirstPartyHTTPHeaders(headers map[string]string) bool {
	total := 0
	for name, value := range headers {
		total += len(name) + len(value)
		if _, ok := firstPartyHTTPHeaders[strings.ToLower(name)]; !ok || !validFirstPartyHTTPHeaderValue(value) {
			return false
		}
	}
	return total <= 16384
}

func firstPartyHTTPNetworkError(ctx context.Context, err error) *MethodError {
	var netErr net.Error
	if errors.Is(ctx.Err(), context.DeadlineExceeded) || errors.Is(err, context.DeadlineExceeded) ||
		(errors.As(err, &netErr) && netErr.Timeout()) {
		return firstPartyHTTPError("timeout")
	}
	if errors.Is(ctx.Err(), context.Canceled) || errors.Is(err, context.Canceled) {
		return firstPartyHTTPError("cancelled")
	}
	return firstPartyHTTPError("network")
}

func firstPartyHTTPError(code string) *MethodError {
	return &MethodError{Code: code, Message: "first-party request failed"}
}

func spillFirstPartyHTTPResponse(id string, data []byte) []byte {
	threshold := responseSpillThreshold
	if runtime.GOOS == "ios" {
		threshold = 2048
	}
	if len(data) <= threshold {
		return data
	}
	dir, err := makeSpilledResponseDir()
	if err == nil {
		var file *os.File
		file, err = os.CreateTemp(dir, "http-*.json")
		if err == nil {
			path := file.Name()
			err = reclaimPrivateFileOwnership(file)
			if err == nil {
				_, err = file.Write(data)
			}
			closeErr := file.Close()
			if err == nil && closeErr == nil {
				return encodeResponse(MethodResponse{ID: id, File: path})
			}
			_ = os.Remove(path)
		}
	}
	return encodeResponse(MethodResponse{ID: id, Error: firstPartyHTTPError("spill_error")})
}
