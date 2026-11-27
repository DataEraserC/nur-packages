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

func newCatalogServer(t *testing.T) *httptest.Server {
	t.Helper()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != catalogPath {
			t.Errorf("catalog path = %q", r.URL.Path)
		}
		if r.Header.Get("Authorization") != "Bearer test-token" {
			t.Errorf("authorization = %q", r.Header.Get("Authorization"))
		}
		_, _ = w.Write([]byte(`{"code":0,"data":{"categories":[{"type":"chat","models":[
			{"model_name":"m1","name":"Model One","description":"first","params":{"context_window":123456,"max_output_tokens":7890}},
			{"model_name":"m2","name":"Model Two","params":{"context_window":2222}}
		]}]}}`))
	}))
	t.Cleanup(server.Close)
	return server
}

func newTestModelStore(t *testing.T) *modelStore {
	t.Helper()
	server := newCatalogServer(t)
	t.Setenv("XIAOHUANXIONG_LLM_ORIGIN", server.URL)
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "auth.json"), []byte(`{"access_token":"test-token"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "config.yaml"), []byte("model: \"m0\"\ncontext_window: 1000\nmax_output_tokens: 100\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	return newModelStore(dir)
}

func TestModelCatalogOptions(t *testing.T) {
	store := newTestModelStore(t)
	options := store.configOptions("s1")
	if len(options) != 1 || options[0].ID != "model" || options[0].Type != "select" {
		t.Fatalf("options = %+v", options)
	}
	if options[0].CurrentValue != "m0" {
		t.Fatalf("current = %q", options[0].CurrentValue)
	}
	values := map[string]bool{}
	for _, option := range options[0].Options {
		values[option.Value] = true
	}
	for _, want := range []string{"m0", "m1", "m2"} {
		if !values[want] {
			t.Fatalf("option %q missing from %+v", want, options[0].Options)
		}
	}
	selection, ok := store.selectModel("s1", "m1")
	if !ok || selection.ContextWindow != 123456 || selection.MaxTokens != 7890 {
		t.Fatalf("selection = %+v ok=%v", selection, ok)
	}
	if _, ok := store.selectModel("s1", "nope"); ok {
		t.Fatal("unknown model was accepted")
	}
	if _, ok := store.selectModel("s2", "m0"); !ok {
		t.Fatal("default model was rejected")
	} else if selection, _ := store.selected("s2"); selection.ContextWindow != 1000 || selection.MaxTokens != 100 {
		t.Fatalf("defaults not applied: %+v", selection)
	}
	reloaded := newModelStore(store.configDir)
	if selection, ok := reloaded.selected("s1"); !ok || selection.Model != "m1" {
		t.Fatalf("selection not persisted: %+v ok=%v", selection, ok)
	}
}

func TestProxyModelSelection(t *testing.T) {
	store := newTestModelStore(t)
	var out strings.Builder
	state := newProxyState(&out, "", store)

	newLine := []byte(`{"jsonrpc":"2.0","id":7,"method":"session/new","params":{"cwd":"/tmp","mcpServers":[]}}` + "\n")
	if got := state.interceptClient(newLine); string(got) != string(newLine) {
		t.Fatalf("session/new was rewritten: %q", got)
	}
	response := []byte(`{"jsonrpc":"2.0","id":7,"result":{"sessionId":"acp-v1-x"}}` + "\n")
	patched := state.rewriteServer(response)
	var parsed struct {
		Result struct {
			ConfigOptions []struct {
				ID           string `json:"id"`
				CurrentValue string `json:"currentValue"`
				Options      []struct {
					Value string `json:"value"`
				} `json:"options"`
			} `json:"configOptions"`
		} `json:"result"`
	}
	if err := json.Unmarshal(patched, &parsed); err != nil {
		t.Fatal(err)
	}
	if len(parsed.Result.ConfigOptions) != 1 || parsed.Result.ConfigOptions[0].CurrentValue != "m0" {
		t.Fatalf("session/new configOptions = %+v", parsed.Result.ConfigOptions)
	}

	selectLine := []byte(`{"jsonrpc":"2.0","id":8,"method":"session/set_config_option","params":{"sessionId":"acp-v1-x","configId":"model","value":"m1"}}` + "\n")
	if answer := state.interceptClient(selectLine); answer != nil {
		t.Fatalf("set_config_option was forwarded: %q", answer)
	}
	var selected struct {
		Result struct {
			ConfigOptions []struct {
				CurrentValue string `json:"currentValue"`
			} `json:"configOptions"`
		} `json:"result"`
	}
	if err := json.Unmarshal([]byte(out.String()), &selected); err != nil {
		t.Fatalf("set_config_option answer = %q", out.String())
	}
	out.Reset()
	if selected.Result.ConfigOptions[0].CurrentValue != "m1" {
		t.Fatalf("current = %+v", selected.Result.ConfigOptions)
	}

	promptLine := []byte(`{"jsonrpc":"2.0","id":9,"method":"session/prompt","params":{"sessionId":"acp-v1-x","prompt":[{"type":"text","text":"hi"}]}}` + "\n")
	prompt := state.interceptClient(promptLine)
	var promptMsg struct {
		Params struct {
			Meta struct {
				Binding struct {
					Source        string `json:"source"`
					Model         string `json:"model"`
					ContextWindow int    `json:"contextWindow"`
					MaxTokens     int    `json:"maxTokens"`
				} `json:"llm_binding"`
			} `json:"_meta"`
		} `json:"params"`
	}
	if err := json.Unmarshal(prompt, &promptMsg); err != nil {
		t.Fatalf("prompt = %q", prompt)
	}
	binding := promptMsg.Params.Meta.Binding
	if binding.Source != "builtin" || binding.Model != "m1" || binding.ContextWindow != 123456 || binding.MaxTokens != 7890 {
		t.Fatalf("binding = %+v", binding)
	}

	state.interceptClient([]byte(`{"jsonrpc":"2.0","id":10,"method":"session/set_config_option","params":{"sessionId":"acp-v1-x","configId":"mode","value":"x"}}` + "\n"))
	if !strings.Contains(out.String(), `"error"`) {
		t.Fatalf("unknown config option was accepted: %q", out.String())
	}
}
