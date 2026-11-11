package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestACPStdio(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		args []string
		want bool
	}{
		{name: "naked invocation", want: false},
		{name: "TUI arguments", args: []string{"--resume", "session-1"}, want: false},
		{name: "ACP default transport", args: []string{"--acp"}, want: true},
		{name: "ACP split stdio transport", args: []string{"--acp", "--acp-transport", "stdio"}, want: true},
		{name: "ACP equals stdio transport", args: []string{"--acp", "--acp-transport=stdio"}, want: true},
		{name: "transport before ACP selector", args: []string{"--acp-transport", "stdio", "--acp"}, want: true},
		{name: "equals transport before ACP selector", args: []string{"--acp-transport=stdio", "--acp"}, want: true},
		{name: "non-stdio ACP transport", args: []string{"--acp", "--acp-transport", "streamable-http"}, want: false},
		{name: "non-stdio transport before ACP", args: []string{"--acp-transport", "streamable-http", "--acp"}, want: false},
		{name: "non-stdio equals transport before ACP", args: []string{"--acp-transport=streamable-http", "--acp"}, want: false},
		{name: "missing transport value", args: []string{"--acp", "--acp-transport"}, want: false},
		{name: "transport without ACP", args: []string{"--acp-transport", "stdio"}, want: false},
		{name: "ACP after terminator is prompt text", args: []string{"--", "--acp"}, want: false},
		{name: "transport after terminator is prompt text", args: []string{"--acp", "--", "--acp-transport", "streamable-http"}, want: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			if got := acpStdio(tt.args); got != tt.want {
				t.Fatalf("acpStdio(%q) = %v, want %v", tt.args, got, tt.want)
			}
		})
	}
}

func TestProxyVersionRequestedHonorsTerminator(t *testing.T) {
	t.Parallel()

	for _, tt := range []struct {
		args []string
		want bool
	}{
		{args: []string{"--acp-proxy-version"}, want: true},
		{args: []string{"--debug", "--acp-proxy-version"}, want: false},
		{args: []string{"--", "--acp-proxy-version"}, want: false},
	} {
		if got := proxyVersionRequested(tt.args); got != tt.want {
			t.Errorf("proxyVersionRequested(%q) = %v, want %v", tt.args, got, tt.want)
		}
	}
}

func TestDispatchExecsRealBinaryForNonACPArgs(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		args []string
	}{
		{name: "bare TUI invocation"},
		{name: "TUI arguments pass through", args: []string{"--resume", "session-1", "prompt with spaces"}},
		{name: "non-stdio ACP passes through", args: []string{"--acp", "--acp-transport", "streamable-http"}},
		{name: "terminator passes through", args: []string{"--", "--acp", "prompt with spaces"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			real := "/nix/store/vendor-codebuddy/bin/codebuddy"
			argv0 := "/run/current-system/sw/bin/codebuddy-acp"
			environ := []string{"HOME=/tmp/home", "TERM=xterm-256color"}
			var gotPath string
			var gotArgv, gotEnviron []string
			served := false

			proxy, err := dispatch(
				real,
				argv0,
				tt.args,
				environ,
				func(path string, argv, env []string) error {
					gotPath = path
					gotArgv = append([]string(nil), argv...)
					gotEnviron = append([]string(nil), env...)
					return nil
				},
				func(string, []string) error {
					served = true
					return nil
				},
			)
			if err != nil {
				t.Fatalf("dispatch() error = %v", err)
			}
			if proxy {
				t.Fatal("dispatch() selected ACP proxy for non-stdio arguments")
			}
			if served {
				t.Fatal("dispatch() started ACP server for non-stdio arguments")
			}
			if gotPath != real {
				t.Errorf("exec path = %q, want %q", gotPath, real)
			}
			wantArgv := append([]string{argv0}, tt.args...)
			if !reflect.DeepEqual(gotArgv, wantArgv) {
				t.Errorf("exec argv = %#v, want %#v", gotArgv, wantArgv)
			}
			if !reflect.DeepEqual(gotEnviron, environ) {
				t.Errorf("exec environ = %#v, want %#v", gotEnviron, environ)
			}
		})
	}
}

func TestDispatchServesACPWithoutExec(t *testing.T) {
	t.Parallel()

	args := []string{"--acp-transport", "stdio", "--acp"}
	executed := false
	var gotReal string
	var gotArgs []string
	proxy, err := dispatch(
		"/vendor/codebuddy",
		"codebuddy-acp",
		args,
		nil,
		func(string, []string, []string) error {
			executed = true
			return nil
		},
		func(real string, args []string) error {
			gotReal = real
			gotArgs = append([]string(nil), args...)
			return nil
		},
	)
	if err != nil {
		t.Fatalf("dispatch() error = %v", err)
	}
	if !proxy {
		t.Fatal("dispatch() did not select ACP proxy")
	}
	if executed {
		t.Fatal("dispatch() execed real binary instead of proxying ACP")
	}
	if gotReal != "/vendor/codebuddy" || !reflect.DeepEqual(gotArgs, args) {
		t.Fatalf("serve call = (%q, %#v), want (%q, %#v)", gotReal, gotArgs, "/vendor/codebuddy", args)
	}
}

func TestRealBinaryPrefersExplicitOverride(t *testing.T) {
	const (
		override = "/caller/vendor/bin/codebuddy"
		compiled = "/nix/store/vendor-codebuddy/bin/codebuddy"
	)
	oldDefault := defaultRealBinary
	defaultRealBinary = compiled
	t.Cleanup(func() { defaultRealBinary = oldDefault })
	t.Setenv("CODEBUDDY_ACP_REAL", override)

	got, err := realBinary()
	if err != nil {
		t.Fatalf("realBinary() error = %v", err)
	}
	if got != override {
		t.Fatalf("realBinary() = %q, want caller override %q", got, override)
	}
}

func TestRealBinaryUsesCompiledDefaultWhenOverrideUnset(t *testing.T) {
	const compiled = "/nix/store/vendor-codebuddy/bin/codebuddy"
	oldDefault := defaultRealBinary
	defaultRealBinary = compiled
	t.Cleanup(func() { defaultRealBinary = oldDefault })
	oldOverride, wasSet := os.LookupEnv("CODEBUDDY_ACP_REAL")
	if err := os.Unsetenv("CODEBUDDY_ACP_REAL"); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if wasSet {
			_ = os.Setenv("CODEBUDDY_ACP_REAL", oldOverride)
		} else {
			_ = os.Unsetenv("CODEBUDDY_ACP_REAL")
		}
	})

	got, err := realBinary()
	if err != nil {
		t.Fatalf("realBinary() error = %v", err)
	}
	if got != compiled {
		t.Fatalf("realBinary() = %q, want compiled default %q", got, compiled)
	}
}

func TestInitializeResponseGainsListCapability(t *testing.T) {
	state := newProxyState(io.Discard)
	request := []byte(`{"jsonrpc":"2.0","id":7,"method":"initialize","params":{}}` + "\n")
	if got := state.interceptClient(request); !bytes.Equal(got, request) {
		t.Fatalf("initialize request changed:\n got %s\nwant %s", got, request)
	}

	response := []byte(`{
		"jsonrpc": "2.0",
		"id": 7,
		"result": {
			"protocolVersion": 1,
			"agentCapabilities": {
				"promptCapabilities": {"image": true},
				"sessionCapabilities": {"fork": {"enabled": true}}
			}
		}
	}` + "\n")
	patched := state.rewriteServer(response)
	if !bytes.HasSuffix(patched, []byte{'\n'}) {
		t.Fatalf("patched response is not newline-delimited: %q", patched)
	}

	var envelope struct {
		Result map[string]any `json:"result"`
	}
	if err := json.Unmarshal(patched, &envelope); err != nil {
		t.Fatalf("unmarshal patched response: %v", err)
	}
	if envelope.Result["protocolVersion"] != float64(1) {
		t.Fatalf("protocolVersion was not preserved: %#v", envelope.Result["protocolVersion"])
	}
	caps, ok := envelope.Result["agentCapabilities"].(map[string]any)
	if !ok {
		t.Fatalf("agentCapabilities has type %T", envelope.Result["agentCapabilities"])
	}
	if _, ok := caps["promptCapabilities"]; !ok {
		t.Fatal("promptCapabilities was not preserved")
	}
	sessions, ok := caps["sessionCapabilities"].(map[string]any)
	if !ok {
		t.Fatalf("sessionCapabilities has type %T", caps["sessionCapabilities"])
	}
	if _, ok := sessions["fork"]; !ok {
		t.Fatal("existing session capability was not preserved")
	}
	list, ok := sessions["list"].(map[string]any)
	if !ok || len(list) != 0 {
		t.Fatalf("list capability = %#v, want empty object", sessions["list"])
	}

	later := []byte(`{"jsonrpc":"2.0","id":7,"result":{"value":"unchanged"}}` + "\n")
	if got := state.rewriteServer(later); !bytes.Equal(got, later) {
		t.Fatalf("later response reusing initialize id changed:\n got %s\nwant %s", got, later)
	}
}

func TestInitializeResponseWithoutCapabilitiesGainsList(t *testing.T) {
	state := newProxyState(io.Discard)
	request := []byte(`{"jsonrpc":"2.0","id":"init","method":"initialize"}` + "\n")
	state.interceptClient(request)
	patched := state.rewriteServer([]byte(`{"jsonrpc":"2.0","id":"init","result":{"protocolVersion":1}}` + "\n"))

	var response struct {
		Result struct {
			AgentCapabilities struct {
				SessionCapabilities map[string]json.RawMessage `json:"sessionCapabilities"`
			} `json:"agentCapabilities"`
		} `json:"result"`
	}
	if err := json.Unmarshal(patched, &response); err != nil {
		t.Fatal(err)
	}
	if got := string(response.Result.AgentCapabilities.SessionCapabilities["list"]); got != "{}" {
		t.Fatalf("list capability = %q, want {}", got)
	}
}

func TestNullInitializeResultPassesThrough(t *testing.T) {
	state := newProxyState(io.Discard)
	state.interceptClient([]byte(`{"jsonrpc":"2.0","id":1,"method":"initialize"}` + "\n"))
	response := []byte(`{"jsonrpc":"2.0","id":1,"result":null}` + "\n")
	if got := state.rewriteServer(response); !bytes.Equal(got, response) {
		t.Fatalf("null initialize result changed:\n got %s\nwant %s", got, response)
	}
}

func TestOtherFramesPassThroughUnchanged(t *testing.T) {
	state := newProxyState(io.Discard)
	initialize := []byte(`{"jsonrpc":"2.0","id":1,"method":"initialize"}` + "\n")
	state.interceptClient(initialize)

	frames := [][]byte{
		[]byte("  {\"jsonrpc\":\"2.0\",\"method\":\"session/update\",\"params\":{}}  \n"),
		[]byte(`{"jsonrpc":"2.0","id":2,"result":{"arbitrary":true}}` + "\n"),
		[]byte("not-json-but-still-a-frame\n"),
	}
	for _, frame := range frames {
		if got := state.interceptClient(frame); !bytes.Equal(got, frame) {
			t.Errorf("client frame changed:\n got %q\nwant %q", got, frame)
		}
		if got := state.rewriteServer(frame); !bytes.Equal(got, frame) {
			t.Errorf("server frame changed:\n got %q\nwant %q", got, frame)
		}
	}
}

func TestProxyStateIsPerServeAndRaceFree(t *testing.T) {
	first := newProxyState(io.Discard)
	second := newProxyState(io.Discard)
	response := []byte(`{"jsonrpc":"2.0","id":1,"result":{"agentCapabilities":{"sessionCapabilities":{}}}}` + "\n")
	request := []byte(`{"jsonrpc":"2.0","id":1,"method":"initialize"}` + "\n")

	if got := second.rewriteServer(response); !bytes.Equal(got, response) {
		t.Fatal("uninitialized proxy instance inherited initialize state")
	}

	start := make(chan struct{})
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		<-start
		for range 1000 {
			first.interceptClient(request)
		}
	}()
	go func() {
		defer wg.Done()
		<-start
		for range 1000 {
			first.rewriteServer(response)
		}
	}()
	close(start)
	wg.Wait()
}

type byteAtATimeWriter struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (w *byteAtATimeWriter) Write(p []byte) (int, error) {
	for _, b := range p {
		w.mu.Lock()
		err := w.buf.WriteByte(b)
		w.mu.Unlock()
		if err != nil {
			return 0, err
		}
		runtime.Gosched()
	}
	return len(p), nil
}

func (w *byteAtATimeWriter) String() string {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.buf.String()
}

func TestFrameWriterDoesNotInterleaveConcurrentFrames(t *testing.T) {
	underlying := &byteAtATimeWriter{}
	writer := &frameWriter{w: underlying}
	const writesPerSide = 200
	left := []byte(`{"source":"local","payload":"aaaaaaaaaaaaaaaa"}` + "\n")
	right := []byte(`{"source":"vendor","payload":"bbbbbbbbbbbbbbbb"}` + "\n")

	start := make(chan struct{})
	var wg sync.WaitGroup
	for _, frame := range [][]byte{left, right} {
		frame := frame
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			for range writesPerSide {
				if _, err := writer.Write(frame); err != nil {
					t.Errorf("write frame: %v", err)
					return
				}
			}
		}()
	}
	close(start)
	wg.Wait()

	lines := strings.Split(strings.TrimSuffix(underlying.String(), "\n"), "\n")
	if len(lines) != writesPerSide*2 {
		t.Fatalf("got %d frames, want %d", len(lines), writesPerSide*2)
	}
	for i, line := range lines {
		var frame map[string]string
		if err := json.Unmarshal([]byte(line), &frame); err != nil {
			t.Fatalf("frame %d was interleaved: %q: %v", i, line, err)
		}
	}
}

type closeBlockingReader struct {
	closed chan struct{}
	once   sync.Once
}

func newCloseBlockingReader() *closeBlockingReader {
	return &closeBlockingReader{closed: make(chan struct{})}
}

func (r *closeBlockingReader) Read([]byte) (int, error) {
	<-r.closed
	return 0, io.EOF
}

func (r *closeBlockingReader) Close() error {
	r.once.Do(func() { close(r.closed) })
	return nil
}

type trackingWriteCloser struct {
	closed chan struct{}
	once   sync.Once
}

func newTrackingWriteCloser() *trackingWriteCloser {
	return &trackingWriteCloser{closed: make(chan struct{})}
}

func (w *trackingWriteCloser) Write(p []byte) (int, error) { return len(p), nil }
func (w *trackingWriteCloser) Close() error {
	w.once.Do(func() { close(w.closed) })
	return nil
}

func TestProxyProcessReturnsWhenVendorExitsBeforeClientEOF(t *testing.T) {
	clientIn := newCloseBlockingReader()
	vendorIn := newTrackingWriteCloser()
	waited := false
	done := make(chan error, 1)
	go func() {
		done <- proxyProcess(clientIn, io.Discard, vendorIn, strings.NewReader(""), func() error {
			waited = true
			return nil
		})
	}()

	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("proxyProcess() error = %v", err)
		}
	case <-time.After(time.Second):
		t.Fatal("proxyProcess blocked waiting for client EOF after vendor exit")
	}
	if !waited {
		t.Fatal("proxyProcess did not wait for vendor process")
	}
	select {
	case <-clientIn.closed:
	default:
		t.Fatal("proxyProcess did not cancel blocked client input")
	}
	select {
	case <-vendorIn.closed:
	default:
		t.Fatal("proxyProcess did not close vendor stdin")
	}
}

func writeTranscript(t *testing.T, configDir, sessionID, cwd, title string, updatedAt time.Time) string {
	t.Helper()
	projectDir := filepath.Join(configDir, "projects", projectSlug(cwd))
	if err := os.MkdirAll(projectDir, 0o755); err != nil {
		t.Fatal(err)
	}
	metadata, err := json.Marshal(map[string]any{"type": "session", "cwd": cwd})
	if err != nil {
		t.Fatal(err)
	}
	prompt, err := json.Marshal(map[string]any{
		"type":    "message",
		"role":    "user",
		"content": []map[string]string{{"text": title}},
	})
	if err != nil {
		t.Fatal(err)
	}
	transcript := filepath.Join(projectDir, sessionID+".jsonl")
	contents := append(append(metadata, '\n'), prompt...)
	contents = append(contents, '\n')
	if err := os.WriteFile(transcript, contents, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(transcript, updatedAt, updatedAt); err != nil {
		t.Fatal(err)
	}
	return transcript
}

func decodeListAnswer(t *testing.T, answer []byte) listResponse {
	t.Helper()
	var response struct {
		JSONRPC string       `json:"jsonrpc"`
		ID      any          `json:"id"`
		Result  listResponse `json:"result"`
		Error   *struct {
			Code    int    `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(answer, &response); err != nil {
		t.Fatalf("unmarshal session/list answer: %v\n%s", err, answer)
	}
	if response.Error != nil {
		t.Fatalf("session/list error = %#v", response.Error)
	}
	if response.JSONRPC != "2.0" {
		t.Fatalf("jsonrpc = %q", response.JSONRPC)
	}
	return response.Result
}

func TestListAnswerUsesLocalTranscript(t *testing.T) {
	configDir := t.TempDir()
	cwd := filepath.Join(t.TempDir(), "repo")
	updatedAt := time.Date(2030, time.February, 3, 4, 5, 6, 0, time.UTC)
	writeTranscript(t, configDir, "session-123", cwd, "  First line\nsecond line  ", updatedAt)

	t.Setenv("CODEBUDDY_CONFIG_DIR", configDir)
	answer := listAnswer(json.RawMessage(`"request-7"`), cwd, "")
	if !bytes.HasSuffix(answer, []byte{'\n'}) {
		t.Fatalf("answer is not newline-delimited: %q", answer)
	}
	result := decodeListAnswer(t, answer)
	if len(result.Sessions) != 1 {
		t.Fatalf("sessions = %#v, want one", result.Sessions)
	}
	got := result.Sessions[0]
	if got.SessionID != "session-123" {
		t.Errorf("sessionId = %q", got.SessionID)
	}
	if got.Cwd != cwd {
		t.Errorf("cwd = %q, want transcript cwd %q", got.Cwd, cwd)
	}
	if got.Title != "First line second line" {
		t.Errorf("title = %q", got.Title)
	}
	if got.UpdatedAt != updatedAt.Format(time.RFC3339Nano) {
		t.Errorf("updatedAt = %q, want %q", got.UpdatedAt, updatedAt.Format(time.RFC3339Nano))
	}
}

func TestListUsesTranscriptCwdWhenDirectorySlugDoesNotMatch(t *testing.T) {
	configDir := t.TempDir()
	cwd := filepath.Join(t.TempDir(), "repo")
	transcript := writeTranscript(t, configDir, "moved-session", cwd, "moved", time.Unix(1, 0))
	unexpectedDir := filepath.Join(configDir, "projects", "intentionally-wrong-slug")
	if err := os.MkdirAll(unexpectedDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Rename(transcript, filepath.Join(unexpectedDir, filepath.Base(transcript))); err != nil {
		t.Fatal(err)
	}
	t.Setenv("CODEBUDDY_CONFIG_DIR", configDir)

	result := decodeListAnswer(t, listAnswer(json.RawMessage(`1`), cwd, ""))
	if len(result.Sessions) != 1 || result.Sessions[0].Cwd != cwd {
		t.Fatalf("sessions = %#v, want transcript cwd %q despite mismatched directory slug", result.Sessions, cwd)
	}
}

func TestListAnswerWithoutCwdUsesTranscriptCwdsAcrossProjects(t *testing.T) {
	configDir := t.TempDir()
	firstCwd := filepath.Join(t.TempDir(), "first")
	secondCwd := filepath.Join(t.TempDir(), "second")
	writeTranscript(t, configDir, "first", firstCwd, "first title", time.Unix(1, 0))
	writeTranscript(t, configDir, "second", secondCwd, "second title", time.Unix(2, 0))
	t.Setenv("CODEBUDDY_CONFIG_DIR", configDir)

	result := decodeListAnswer(t, listAnswer(json.RawMessage(`1`), "", ""))
	if len(result.Sessions) != 2 {
		t.Fatalf("sessions = %#v, want two", result.Sessions)
	}
	got := []string{result.Sessions[0].Cwd, result.Sessions[1].Cwd}
	sort.Strings(got)
	want := []string{firstCwd, secondCwd}
	sort.Strings(want)
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("cwds = %#v, want transcript cwds %#v", got, want)
	}
}

func TestUnsetConfigDirUsesDefaultProfile(t *testing.T) {
	home := t.TempDir()
	defaultConfig := filepath.Join(home, ".codebuddy")
	cwd := filepath.Join(t.TempDir(), "repo")
	writeTranscript(t, defaultConfig, "default-profile", cwd, "visible", time.Unix(1, 0))
	t.Setenv("HOME", home)
	oldConfigDir, wasSet := os.LookupEnv("CODEBUDDY_CONFIG_DIR")
	if err := os.Unsetenv("CODEBUDDY_CONFIG_DIR"); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if wasSet {
			_ = os.Setenv("CODEBUDDY_CONFIG_DIR", oldConfigDir)
		} else {
			_ = os.Unsetenv("CODEBUDDY_CONFIG_DIR")
		}
	})

	result := decodeListAnswer(t, listAnswer(json.RawMessage(`1`), cwd, ""))
	if len(result.Sessions) != 1 || result.Sessions[0].SessionID != "default-profile" {
		t.Fatalf("unset config dir sessions = %#v, want default profile", result.Sessions)
	}
}

func TestExplicitlyEmptyConfigDirDoesNotFallBackToDefaultProfile(t *testing.T) {
	home := t.TempDir()
	defaultConfig := filepath.Join(home, ".codebuddy")
	cwd := filepath.Join(t.TempDir(), "repo")
	writeTranscript(t, defaultConfig, "default-profile", cwd, "secret", time.Unix(1, 0))
	t.Setenv("HOME", home)
	t.Setenv("CODEBUDDY_CONFIG_DIR", "")

	if _, err := transcriptBase(); err == nil {
		t.Fatal("transcriptBase accepted an explicitly empty CODEBUDDY_CONFIG_DIR")
	}
	answer := listAnswer(json.RawMessage(`1`), cwd, "")
	var raw struct {
		Result map[string]json.RawMessage `json:"result"`
	}
	if err := json.Unmarshal(answer, &raw); err != nil {
		t.Fatal(err)
	}
	if got := string(raw.Result["sessions"]); got != "[]" {
		t.Fatalf("empty config dir sessions JSON = %s, want []", got)
	}
	result := decodeListAnswer(t, answer)
	if len(result.Sessions) != 0 {
		t.Fatalf("explicitly empty config dir leaked default sessions: %#v", result.Sessions)
	}
}

func TestExplicitConfigDirDoesNotFallBackToDefaultProfile(t *testing.T) {
	home := t.TempDir()
	defaultConfig := filepath.Join(home, ".codebuddy")
	cwd := filepath.Join(t.TempDir(), "repo")
	writeTranscript(t, defaultConfig, "default-profile", cwd, "secret", time.Unix(1, 0))
	t.Setenv("HOME", home)
	t.Setenv("CODEBUDDY_CONFIG_DIR", filepath.Join(t.TempDir(), "empty-profile"))

	answer := listAnswer(json.RawMessage(`1`), cwd, "")
	var raw struct {
		Result map[string]json.RawMessage `json:"result"`
	}
	if err := json.Unmarshal(answer, &raw); err != nil {
		t.Fatal(err)
	}
	if got := string(raw.Result["sessions"]); got != "[]" {
		t.Fatalf("empty sessions JSON = %s, want []", got)
	}
	result := decodeListAnswer(t, answer)
	if len(result.Sessions) != 0 {
		t.Fatalf("explicit empty profile leaked default sessions: %#v", result.Sessions)
	}
}

func TestSessionListPagination(t *testing.T) {
	configDir := t.TempDir()
	cwd := filepath.Join(t.TempDir(), "repo")
	base := time.Date(2030, time.January, 1, 0, 0, 0, 0, time.UTC)
	for i := 0; i < listLimit+3; i++ {
		writeTranscript(t, configDir, fmt.Sprintf("session-%03d", i), cwd, fmt.Sprintf("title %d", i), base.Add(time.Duration(i)*time.Second))
	}
	t.Setenv("CODEBUDDY_CONFIG_DIR", configDir)

	first := decodeListAnswer(t, listAnswer(json.RawMessage(`1`), cwd, ""))
	if len(first.Sessions) != listLimit || first.NextCursor == "" {
		t.Fatalf("first page has %d sessions and cursor %q", len(first.Sessions), first.NextCursor)
	}
	second := decodeListAnswer(t, listAnswer(json.RawMessage(`2`), cwd, first.NextCursor))
	if len(second.Sessions) != 3 || second.NextCursor != "" {
		t.Fatalf("second page has %d sessions and cursor %q", len(second.Sessions), second.NextCursor)
	}

	seen := make(map[string]bool)
	for _, session := range append(first.Sessions, second.Sessions...) {
		if seen[session.SessionID] {
			t.Fatalf("duplicate session across pages: %s", session.SessionID)
		}
		seen[session.SessionID] = true
	}
	if len(seen) != listLimit+3 {
		t.Fatalf("pagination returned %d unique sessions, want %d", len(seen), listLimit+3)
	}
}

func TestInvalidSessionListCursorReturnsInvalidParams(t *testing.T) {
	t.Setenv("CODEBUDDY_CONFIG_DIR", t.TempDir())
	answer := listAnswer(json.RawMessage(`7`), "", "not-base64!")
	var response struct {
		Error struct {
			Code int `json:"code"`
		} `json:"error"`
	}
	if err := json.Unmarshal(answer, &response); err != nil {
		t.Fatal(err)
	}
	if response.Error.Code != -32602 {
		t.Fatalf("error code = %d, want -32602", response.Error.Code)
	}
}
