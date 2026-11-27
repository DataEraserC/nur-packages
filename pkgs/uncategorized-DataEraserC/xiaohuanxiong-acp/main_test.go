package main

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestAddListCapabilityPreservesResume(t *testing.T) {
	result, err := addListCapability(json.RawMessage(`{"agentCapabilities":{"loadSession":true,"sessionCapabilities":{"resume":{}}},"agentInfo":{"name":"box-agent"}}`))
	if err != nil {
		t.Fatal(err)
	}
	var parsed struct {
		AgentCapabilities struct {
			LoadSession         bool                       `json:"loadSession"`
			SessionCapabilities map[string]json.RawMessage `json:"sessionCapabilities"`
		} `json:"agentCapabilities"`
	}
	if err := json.Unmarshal(result, &parsed); err != nil {
		t.Fatal(err)
	}
	if !parsed.AgentCapabilities.LoadSession {
		t.Fatal("loadSession was dropped")
	}
	if _, ok := parsed.AgentCapabilities.SessionCapabilities["resume"]; !ok {
		t.Fatal("resume capability was dropped")
	}
	if _, ok := parsed.AgentCapabilities.SessionCapabilities["list"]; !ok {
		t.Fatal("list capability was not added")
	}
}

func TestRewriteNewAsLoad(t *testing.T) {
	line := []byte(`{"jsonrpc":"2.0","id":7,"method":"session/new","params":{"cwd":"/tmp/work","mcpServers":[]}}` + "\n")
	out, err := rewriteNewAsLoad(line, "acp-v1-abc")
	if err != nil {
		t.Fatal(err)
	}
	var msg struct {
		Method string `json:"method"`
		Params struct {
			Cwd       string `json:"cwd"`
			SessionID string `json:"sessionId"`
		} `json:"params"`
	}
	if err := json.Unmarshal(out, &msg); err != nil {
		t.Fatal(err)
	}
	if msg.Method != "session/load" {
		t.Fatalf("method = %q", msg.Method)
	}
	if msg.Params.SessionID != "acp-v1-abc" || msg.Params.Cwd != "/tmp/work" {
		t.Fatalf("params = %+v", msg.Params)
	}
}

func TestListSessions(t *testing.T) {
	home := t.TempDir()
	t.Setenv("BOX_AGENT_HOME", home)
	now := time.Now().UTC()

	writeSession := func(dir, uuid, cwd, title string, mtime time.Time) {
		path := filepath.Join(home, "sessions", dir)
		if err := os.MkdirAll(path, 0o755); err != nil {
			t.Fatal(err)
		}
		content := `{"type":"session","version":1,"id":"` + uuid + `","cwd":"` + cwd + `"}` + "\n" +
			`{"type":"user/message","data":{"role":"user","source":"user","content":"` + title + `"}}` + "\n"
		file := filepath.Join(path, "session.jsonl")
		if err := os.WriteFile(file, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
		if err := os.Chtimes(file, mtime, mtime); err != nil {
			t.Fatal(err)
		}
	}

	writeSession("a", "uuid-a", "/work/one", "older prompt", now.Add(-time.Hour))
	writeSession("b", "uuid-b", "/work/one", "newer prompt", now)
	writeSession("c", "uuid-c", "/work/two", "other prompt", now.Add(-time.Minute))

	all := listSessions("")
	if len(all) != 3 {
		t.Fatalf("len(all) = %d, want 3", len(all))
	}
	if all[0].SessionID != acpSessionID("uuid-b") || all[0].Title != "newer prompt" {
		t.Fatalf("first = %+v", all[0])
	}
	if all[0].UpdatedAt != now.Format(time.RFC3339Nano) {
		t.Fatalf("updatedAt = %q", all[0].UpdatedAt)
	}

	filtered := listSessions("/work/one")
	if len(filtered) != 2 {
		t.Fatalf("len(filtered) = %d, want 2", len(filtered))
	}
	if filtered[0].SessionID != acpSessionID("uuid-b") {
		t.Fatalf("filtered order = %+v", filtered)
	}

	page, cursor, err := paginateSessions(all, "")
	if err != nil {
		t.Fatal(err)
	}
	if len(page) != 3 || cursor != "" {
		t.Fatalf("unexpected page len=%d cursor=%q", len(page), cursor)
	}

	badCursor := page[len(page)-1]
	encoded, err := json.Marshal(sessionCursor{
		SessionID: badCursor.SessionID,
		Cwd:       badCursor.Cwd,
		UpdatedAt: badCursor.UpdatedAt,
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := paginateSessions(all, string(encoded)); err == nil {
		t.Fatal("non-base64 cursor was accepted")
	}
}

func TestLoginWithCodeWritesAuth(t *testing.T) {
	var sawPath string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sawPath = r.URL.Path
		if r.Method != http.MethodPost || r.URL.Path != "/login_with_authorization_code" {
			t.Errorf("unexpected request %s %s", r.Method, r.URL.Path)
		}
		_, _ = w.Write([]byte(`{"code":0,"data":{"access_token":"access-secret","refresh_token":"refresh-secret","office_identity":"org-1","office_org_name":"Org","office_org_role":"admin"}}`))
	}))
	defer server.Close()
	t.Setenv("XIAOHUANXIONG_AUTH_BASE", server.URL)

	state := localState{configDir: t.TempDir()}
	if err := loginWithCode(state, "auth-code"); err != nil {
		t.Fatal(err)
	}
	if sawPath != "/login_with_authorization_code" {
		t.Fatalf("path = %q", sawPath)
	}
	raw, err := os.ReadFile(authPath(state))
	if err != nil {
		t.Fatal(err)
	}
	var payload map[string]string
	if err := json.Unmarshal(raw, &payload); err != nil {
		t.Fatal(err)
	}
	if payload["access_token"] != "access-secret" || payload["refresh_token"] != "refresh-secret" {
		t.Fatalf("auth payload = %+v", payload)
	}
	if payload["office_identity"] != "org-1" || payload["office_org_role"] != "admin" {
		t.Fatalf("office fields = %+v", payload)
	}
	info, err := os.Stat(authPath(state))
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("auth mode = %o", info.Mode().Perm())
	}
	if strings.Contains(string(raw), "Authorization") {
		t.Fatal("auth file contains a header")
	}
}

func TestQRCodeFormat(t *testing.T) {
	code, err := newQRCode()
	if err != nil {
		t.Fatal(err)
	}
	if len(code) != 45 {
		t.Fatalf("code length = %d, want 45", len(code))
	}
	if strings.Trim(code[:13], "0123456789") != "" {
		t.Fatalf("code prefix = %q", code[:13])
	}
	if strings.Trim(code[13:], "0123456789abcdef") != "" {
		t.Fatalf("code nonce = %q", code[13:])
	}
}

func TestLoginWebLoopbackWritesAuth(t *testing.T) {
	var sawPath string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sawPath = r.URL.Path
		if r.Method != http.MethodPost || r.URL.Path != "/login_with_authorization_code" {
			t.Errorf("unexpected request %s %s", r.Method, r.URL.Path)
		}
		var payload map[string]string
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Errorf("decode: %v", err)
		}
		if payload["authorization_code"] != "web-code" {
			t.Errorf("authorization_code = %q", payload["authorization_code"])
		}
		_, _ = w.Write([]byte(`{"code":0,"data":{"access_token":"iam-access","office_identity":"org-1","office_org_name":"Org","office_org_role":"admin"}}`))
	}))
	defer server.Close()
	t.Setenv("XIAOHUANXIONG_AUTH_BASE", server.URL)
	t.Setenv("XIAOHUANXIONG_LOGIN_BASE", "https://login.example")

	state := localState{configDir: t.TempDir()}
	links := make(chan string, 1)
	result := make(chan error, 1)
	go func() {
		result <- loginWebWith(state, 5*time.Second, func(link string) { links <- link })
	}()

	link := <-links
	parsed, err := url.Parse(link)
	if err != nil {
		t.Fatal(err)
	}
	if parsed.Scheme != "https" || parsed.Host != "login.example" || parsed.Path != "/authorize" {
		t.Fatalf("login link = %q", link)
	}
	query := parsed.Query()
	if query.Get("login_source") != "desktop" || query.Get("desktop_callback") != "loopback" {
		t.Fatalf("login params = %v", query)
	}
	redirect, nonce := query.Get("redirect"), query.Get("state")
	if len(nonce) != 64 || !strings.HasPrefix(redirect, "http://127.0.0.1:") ||
		!strings.HasSuffix(redirect, "/auth/callback") {
		t.Fatalf("redirect = %q state = %q", redirect, nonce)
	}

	callback := redirect + "?code=web-code&state=" + url.QueryEscape(nonce)
	response, err := http.Get(callback)
	if err != nil {
		t.Fatal(err)
	}
	body := make([]byte, 4096)
	n, _ := response.Body.Read(body)
	response.Body.Close()
	if response.StatusCode != http.StatusOK || !strings.Contains(string(body[:n]), "登录成功") {
		t.Fatalf("callback status = %d body = %q", response.StatusCode, body[:n])
	}
	if err := <-result; err != nil {
		t.Fatal(err)
	}
	if sawPath != "/login_with_authorization_code" {
		t.Fatalf("exchange path = %q", sawPath)
	}
	raw, err := os.ReadFile(authPath(state))
	if err != nil {
		t.Fatal(err)
	}
	var payload map[string]string
	if err := json.Unmarshal(raw, &payload); err != nil {
		t.Fatal(err)
	}
	if payload["access_token"] != "iam-access" || payload["refresh_token"] != "" {
		t.Fatalf("auth payload = %+v", payload)
	}
}

func TestLoginWebRejectsForeignState(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("exchange must not run for a foreign state")
	}))
	defer server.Close()
	t.Setenv("XIAOHUANXIONG_AUTH_BASE", server.URL)
	t.Setenv("XIAOHUANXIONG_LOGIN_BASE", "https://login.example")

	state := localState{configDir: t.TempDir()}
	links := make(chan string, 1)
	result := make(chan error, 1)
	go func() {
		result <- loginWebWith(state, 300*time.Millisecond, func(link string) { links <- link })
	}()

	parsed, err := url.Parse(<-links)
	if err != nil {
		t.Fatal(err)
	}
	query := parsed.Query()
	response, err := http.Get(query.Get("redirect") + "?code=web-code&state=" + strings.Repeat("a", 64))
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusBadRequest {
		t.Fatalf("callback status = %d", response.StatusCode)
	}
	if err := <-result; err == nil || !strings.Contains(err.Error(), "超时") {
		t.Fatalf("login result = %v", err)
	}
	if _, err := os.Stat(authPath(state)); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("auth file exists: %v", err)
	}
}
