package main

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"html"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

// The web login mirrors the desktop client's Linux compatibility path: the
// browser opens /authorize, and the site redirects back to a one-shot loopback
// receiver instead of the office-raccoon:// deep link. The receiver's port is
// ephemeral, the state binds the callback to this attempt, and the code is
// exchanged for credentials exactly like --login-code.

const (
	defaultLoginBase = "https://xiaohuanxiong.com"
	webLoginLifetime = 5 * time.Minute
	webLoginAppName  = "商汤小浣熊客户端"
)

func loginBase() string {
	base := os.Getenv("XIAOHUANXIONG_LOGIN_BASE")
	if base == "" {
		base = defaultLoginBase
	}
	return strings.TrimRight(base, "/")
}

func loginWeb(state localState) error {
	return loginWebWith(state, webLoginLifetime, nil)
}

func randomHex(size int) (string, error) {
	buf := make([]byte, size)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

func loopbackRemote(remoteAddr string) bool {
	host, _, err := net.SplitHostPort(remoteAddr)
	if err != nil {
		return false
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

// webLoginCode validates a loopback callback and returns the authorization code.
func webLoginCode(state string, target *url.URL) (string, bool) {
	if target.Path != "/auth/callback" || target.RawQuery == "" || len(target.RawQuery) > 8192 {
		return "", false
	}
	query := target.Query()
	if len(query) != 2 {
		return "", false
	}
	states, codes := query["state"], query["code"]
	if len(states) != 1 || len(codes) != 1 || len(states[0]) != len(state) {
		return "", false
	}
	if subtle.ConstantTimeCompare([]byte(states[0]), []byte(state)) != 1 {
		return "", false
	}
	code := codes[0]
	if strings.TrimSpace(code) == "" || len(code) > 4096 {
		return "", false
	}
	for _, character := range code {
		if character < 0x20 || character == 0x7f {
			return "", false
		}
	}
	return code, true
}

func webPage(response http.ResponseWriter, status int, message string) {
	response.Header().Set("Content-Type", "text/html; charset=utf-8")
	response.Header().Set("Cache-Control", "no-store")
	response.Header().Set("Referrer-Policy", "no-referrer")
	response.Header().Set("X-Content-Type-Options", "nosniff")
	response.Header().Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; base-uri 'none'")
	response.WriteHeader(status)
	fmt.Fprintf(response, "<!doctype html><html lang=\"zh\"><meta charset=\"utf-8\"><title>商汤小浣熊</title><h1>%s</h1><p>可以关闭此页面。</p></html>", html.EscapeString(message))
}

func loginWebWith(state localState, lifetime time.Duration, emit func(link string)) error {
	nonce, err := randomHex(32)
	if err != nil {
		return err
	}

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return fmt.Errorf("无法启动本地登录回调: %w", err)
	}
	defer listener.Close()

	authority := listener.Addr().(*net.TCPAddr).String()
	redirect := "http://" + authority + "/auth/callback"
	link := loginBase() + "/authorize?" + url.Values{
		"login_source":     {"desktop"},
		"appname":          {webLoginAppName},
		"desktop_callback": {"loopback"},
		"redirect":         {redirect},
		"state":            {nonce},
	}.Encode()

	origin, err := url.Parse(loginBase())
	if err != nil {
		return fmt.Errorf("登录地址无效: %w", err)
	}
	allowedOrigin := origin.Scheme + "://" + origin.Host

	codes := make(chan string, 1)
	finished := make(chan error, 1)
	responded := make(chan struct{})
	var respondOnce sync.Once
	signalResponded := func() { respondOnce.Do(func() { close(responded) }) }
	var consumeOnce sync.Once

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(response http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodGet ||
			request.Host != authority ||
			!loopbackRemote(request.RemoteAddr) {
			webPage(response, http.StatusForbidden, "登录回调无效，请从终端重新发起")
			signalResponded()
			return
		}
		if requestOrigin := request.Header.Get("Origin"); requestOrigin != "" && requestOrigin != allowedOrigin {
			webPage(response, http.StatusForbidden, "登录回调无效，请从终端重新发起")
			signalResponded()
			return
		}
		code, ok := webLoginCode(nonce, request.URL)
		if !ok {
			webPage(response, http.StatusBadRequest, "登录回调无效，请从终端重新发起")
			signalResponded()
			return
		}
		first := false
		consumeOnce.Do(func() {
			first = true
			codes <- code
		})
		if !first {
			webPage(response, http.StatusConflict, "此登录请求已处理")
			signalResponded()
			return
		}
		select {
		case err := <-finished:
			if err != nil {
				webPage(response, http.StatusBadGateway, "登录未完成，请从终端重试")
			} else {
				webPage(response, http.StatusOK, "登录成功，请返回终端")
			}
		case <-time.After(45 * time.Second):
			webPage(response, http.StatusGatewayTimeout, "等待凭据写入超时，请查看终端")
		}
		signalResponded()
	})

	server := &http.Server{Handler: mux, ReadHeaderTimeout: 10 * time.Second}
	defer server.Close()
	serveErr := make(chan error, 1)
	go func() {
		if err := server.Serve(listener); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serveErr <- err
		}
	}()

	fmt.Println("请在浏览器中打开以下链接完成登录（5 分钟内有效）：")
	fmt.Println(link)
	fmt.Println("登录完成后终端会自动继续；也可以把回调里的 code 通过 --login-code 传入。")
	if emit != nil {
		emit(link)
	}

	client := &http.Client{Timeout: 30 * time.Second}
	select {
	case code := <-codes:
		creds, err := exchangeAuthorizationCode(context.Background(), client, code)
		if err == nil {
			err = saveAuth(state, creds)
		}
		finished <- err
		if err != nil {
			select {
			case <-responded:
			case <-time.After(2 * time.Second):
			}
			return err
		}
		fmt.Println("登录成功，凭据已写入", authPath(state))
		select {
		case <-responded:
		case <-time.After(2 * time.Second):
		}
		return nil
	case err := <-serveErr:
		return err
	case <-time.After(lifetime):
		return errors.New("网页登录超时，请重新运行 --login")
	}
}
