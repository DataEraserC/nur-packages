// codebuddy-acp is a stdio proxy in front of `codebuddy --acp` that fills the
// gaps in CodeBuddy's Agent Client Protocol server. CodeBuddy 2.180.0 answers
// session/new, session/load and session/prompt but not session/list, which
// makes it unusable as a hybrid agent in clients that discover sessions by
// listing them. The proxy forwards every frame unchanged except:
//
//   - initialize responses gain agentCapabilities.sessionCapabilities.list, so
//     clients that require it accept the agent;
//   - session/list requests are answered from CodeBuddy's own transcript store
//     (~/.codebuddy/projects/<cwd-slug>/<session-id>.jsonl) instead of being
//     forwarded, where they would fail with -32601.
//
// When the arguments do not select stdio ACP, the proxy execs the real binary,
// so the TUI, --print and other transports behave exactly as before.
package main

import (
	"bufio"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	// listLimit bounds one session/list answer; clients page with cursors and
	// never expect an unbounded reply.
	listLimit = 200
	// headLines is how many transcript records are read to recover cwd/title.
	headLines = 40
	// titleLimit truncates a recovered first prompt for the session label.
	titleLimit = 80
)

type sessionInfo struct {
	SessionID string `json:"sessionId"`
	Cwd       string `json:"cwd"`
	Title     string `json:"title,omitempty"`
	UpdatedAt string `json:"updatedAt,omitempty"`
}

type listResponse struct {
	Sessions   []sessionInfo `json:"sessions"`
	NextCursor string        `json:"nextCursor,omitempty"`
}

type proxyState struct {
	mu     sync.Mutex
	initID string
	out    *frameWriter
}

type frameWriter struct {
	mu sync.Mutex
	w  io.Writer
}

func (w *frameWriter) Write(p []byte) (int, error) {
	w.mu.Lock()
	defer w.mu.Unlock()

	written := 0
	for len(p) > 0 {
		n, err := w.w.Write(p)
		written += n
		p = p[n:]
		if err != nil {
			return written, err
		}
		if n == 0 {
			return written, io.ErrShortWrite
		}
	}
	return written, nil
}

func newProxyState(out io.Writer) *proxyState {
	return &proxyState{out: &frameWriter{w: out}}
}

// version and defaultRealBinary are set at build time. The proxy answers only
// its exact --acp-proxy-version invocation; every other non-stdio invocation
// execs the caller override or the compiled-in vendor binary.
var (
	version           = "dev"
	defaultRealBinary string
)

func main() {
	if proxyVersionRequested(os.Args[1:]) {
		fmt.Println(version)
		return
	}
	args := os.Args[1:]
	real, err := realBinary()
	if err != nil {
		fmt.Fprintln(os.Stderr, "codebuddy-acp:", err)
		os.Exit(2)
	}
	proxy, err := dispatch(real, os.Args[0], args, os.Environ(), syscall.Exec, serve)
	if err == nil {
		return
	}
	if proxy {
		fmt.Fprintln(os.Stderr, "codebuddy-acp:", err)
		os.Exit(1)
	}
	fmt.Fprintln(os.Stderr, "codebuddy-acp: exec:", err)
	os.Exit(2)
}

// dispatch either replaces this process with the real CLI or runs the ACP
// proxy. Its injected functions keep the exec boundary testable without a
// subprocess replacing the test runner.
func dispatch(
	real, argv0 string,
	args, environ []string,
	execReal func(string, []string, []string) error,
	serveACP func(string, []string) error,
) (bool, error) {
	if !acpStdio(args) {
		return false, execReal(real, append([]string{argv0}, args...), environ)
	}
	return true, serveACP(real, args)
}

func proxyVersionRequested(args []string) bool {
	return len(args) == 1 && args[0] == "--acp-proxy-version"
}

// acpStdio reports whether these arguments select the stdio ACP server, the
// only transport a line proxy can sit in front of.
func acpStdio(args []string) bool {
	acp := false
	transport := "stdio"
	for i := 0; i < len(args); i++ {
		if args[i] == "--" {
			break
		}
		switch {
		case args[i] == "--acp":
			acp = true
		case args[i] == "--acp-transport":
			if i+1 >= len(args) {
				return false
			}
			i++
			transport = args[i]
		case strings.HasPrefix(args[i], "--acp-transport="):
			transport = strings.TrimPrefix(args[i], "--acp-transport=")
		}
	}
	return acp && transport == "stdio"
}

// realBinary locates the real CLI: a non-empty caller override first, then the
// linker-injected package default.
func realBinary() (string, error) {
	if p := os.Getenv("CODEBUDDY_ACP_REAL"); p != "" {
		return p, nil
	}
	if defaultRealBinary != "" {
		return defaultRealBinary, nil
	}
	return "", errors.New("real CodeBuddy path is not configured (set CODEBUDDY_ACP_REAL or build with main.defaultRealBinary)")
}

// serve runs the real ACP server and shuttles frames in both directions.
func serve(real string, args []string) error {
	cmd := exec.Command(real, args...)
	cmd.Stderr = os.Stderr
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	if err := cmd.Start(); err != nil {
		return err
	}

	return proxyProcess(os.Stdin, os.Stdout, stdin, stdout, cmd.Wait)
}

func proxyProcess(
	clientIn io.ReadCloser,
	clientOut io.Writer,
	vendorIn io.WriteCloser,
	vendorOut io.Reader,
	waitVendor func() error,
) error {
	state := newProxyState(clientOut)
	var closeVendorIn sync.Once
	closeInput := func() {
		closeVendorIn.Do(func() { _ = vendorIn.Close() })
	}
	go func() {
		forward(clientIn, vendorIn, state.interceptClient)
		closeInput()
	}()
	forward(vendorOut, state.out, state.rewriteServer)
	_ = clientIn.Close()
	closeInput()
	return waitVendor()
}

// forward copies newline-delimited frames from src to dst, passing each one
// through transform. A dropped frame is simply not written.
func forward(src io.Reader, dst io.Writer, transform func(line []byte) []byte) {
	r := bufio.NewReaderSize(src, 1<<20)
	for {
		line, err := r.ReadBytes('\n')
		if len(line) > 0 {
			if out := transform(line); len(out) > 0 {
				writeAll(dst, out)
			}
		}
		if err != nil {
			return
		}
	}
}

func writeAll(dst io.Writer, p []byte) {
	for len(p) > 0 {
		n, err := dst.Write(p)
		p = p[n:]
		if err != nil || n == 0 {
			return
		}
	}
}

// interceptClient drops session/list (answered locally) and remembers the
// initialize id so its response can be patched. Every other frame passes.
func (s *proxyState) interceptClient(line []byte) []byte {
	var msg struct {
		ID     json.RawMessage `json:"id"`
		Method string          `json:"method"`
		Params struct {
			Cwd    string `json:"cwd"`
			Cursor string `json:"cursor"`
		} `json:"params"`
	}
	if json.Unmarshal(line, &msg) != nil || len(msg.ID) == 0 {
		return line
	}
	switch msg.Method {
	case "initialize":
		s.mu.Lock()
		s.initID = string(msg.ID)
		s.mu.Unlock()
		return line
	case "session/list":
		_, _ = s.out.Write(listAnswer(msg.ID, msg.Params.Cwd, msg.Params.Cursor))
		return nil
	}
	return line
}

// rewriteServer injects the session/list capability into the initialize
// response and passes everything else through untouched.
func (s *proxyState) rewriteServer(line []byte) []byte {
	var msg map[string]json.RawMessage
	if json.Unmarshal(line, &msg) != nil {
		return line
	}
	id, ok := msg["id"]
	if !ok {
		return line
	}
	s.mu.Lock()
	if s.initID == "" || string(id) != s.initID {
		s.mu.Unlock()
		return line
	}
	if _, hasResult := msg["result"]; !hasResult {
		if _, hasError := msg["error"]; !hasError {
			s.mu.Unlock()
			return line
		}
	}
	s.initID = ""
	s.mu.Unlock()

	result, ok := msg["result"]
	if !ok {
		return line
	}
	patched, err := addListCapability(result)
	if err != nil {
		return line
	}
	msg["result"] = patched
	out, err := json.Marshal(msg)
	if err != nil {
		return line
	}
	return append(out, '\n')
}

// addListCapability merges {"list":{}} into agentCapabilities.sessionCapabilities.
func addListCapability(result json.RawMessage) (json.RawMessage, error) {
	var res map[string]json.RawMessage
	if err := json.Unmarshal(result, &res); err != nil {
		return nil, err
	}
	if res == nil {
		return nil, errors.New("initialize result is null")
	}
	caps := map[string]json.RawMessage{}
	if rawCaps, ok := res["agentCapabilities"]; ok && len(rawCaps) > 0 && string(rawCaps) != "null" {
		if err := json.Unmarshal(rawCaps, &caps); err != nil {
			return nil, err
		}
	}
	sessions := map[string]json.RawMessage{}
	if raw, ok := caps["sessionCapabilities"]; ok && len(raw) > 0 && string(raw) != "null" {
		if err := json.Unmarshal(raw, &sessions); err != nil {
			return nil, err
		}
	}
	if _, ok := sessions["list"]; !ok {
		sessions["list"] = json.RawMessage(`{}`)
	}
	encoded, err := json.Marshal(sessions)
	if err != nil {
		return nil, err
	}
	caps["sessionCapabilities"] = encoded
	encoded, err = json.Marshal(caps)
	if err != nil {
		return nil, err
	}
	res["agentCapabilities"] = encoded
	return json.Marshal(res)
}

type sessionCursor struct {
	SessionID string `json:"sessionId"`
	Cwd       string `json:"cwd"`
	UpdatedAt string `json:"updatedAt"`
}

// listAnswer builds a session/list response from CodeBuddy's transcripts.
func listAnswer(id json.RawMessage, cwd, cursor string) []byte {
	sessions := listSessions(cwd)
	if sessions == nil {
		sessions = []sessionInfo{}
	}
	page, nextCursor, err := paginateSessions(sessions, cursor)
	if err != nil {
		return errorAnswer(id, -32602, "invalid session/list cursor")
	}
	resp := map[string]json.RawMessage{
		"jsonrpc": json.RawMessage(`"2.0"`),
		"id":      id,
	}
	body, err := json.Marshal(listResponse{Sessions: page, NextCursor: nextCursor})
	if err != nil {
		return errorAnswer(id, -32603, "session/list failed")
	}
	resp["result"] = body
	out, err := json.Marshal(resp)
	if err != nil {
		return errorAnswer(id, -32603, "session/list failed")
	}
	return append(out, '\n')
}

func errorAnswer(id json.RawMessage, code int, message string) []byte {
	resp := struct {
		JSONRPC string          `json:"jsonrpc"`
		ID      json.RawMessage `json:"id"`
		Error   struct {
			Code    int    `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
	}{JSONRPC: "2.0", ID: id}
	resp.Error.Code = code
	resp.Error.Message = message
	out, err := json.Marshal(resp)
	if err != nil {
		return []byte("{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32603,\"message\":\"session/list failed\"}}\n")
	}
	return append(out, '\n')
}

func paginateSessions(sessions []sessionInfo, cursor string) ([]sessionInfo, string, error) {
	start := 0
	if cursor != "" {
		decoded, err := base64.RawURLEncoding.DecodeString(cursor)
		if err != nil {
			return nil, "", err
		}
		var marker sessionCursor
		if err := json.Unmarshal(decoded, &marker); err != nil {
			return nil, "", err
		}
		if marker.SessionID == "" || marker.Cwd == "" || marker.UpdatedAt == "" {
			return nil, "", errors.New("incomplete cursor")
		}
		found := false
		for i, session := range sessions {
			if session.SessionID == marker.SessionID && session.Cwd == marker.Cwd && session.UpdatedAt == marker.UpdatedAt {
				start = i + 1
				found = true
				break
			}
		}
		if !found {
			return nil, "", errors.New("cursor session not found")
		}
	}

	end := min(start+listLimit, len(sessions))
	page := sessions[start:end]
	if end == len(sessions) {
		return page, "", nil
	}
	last := page[len(page)-1]
	encoded, err := json.Marshal(sessionCursor{
		SessionID: last.SessionID,
		Cwd:       last.Cwd,
		UpdatedAt: last.UpdatedAt,
	})
	if err != nil {
		return nil, "", err
	}
	return page, base64.RawURLEncoding.EncodeToString(encoded), nil
}

// transcriptBase is CodeBuddy's transcript root. The CLI stores transcripts in
// $CODEBUDDY_CONFIG_DIR/projects when an isolated profile is selected, and in
// ~/.codebuddy/projects when the variable is unset. An explicitly empty value
// is invalid and must not fall back to the default profile.
func transcriptBase() (string, error) {
	if dir, set := os.LookupEnv("CODEBUDDY_CONFIG_DIR"); set {
		if dir == "" {
			return "", errors.New("CODEBUDDY_CONFIG_DIR is set but empty")
		}
		return filepath.Join(dir, "projects"), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".codebuddy", "projects"), nil
}

// listSessions reads the transcript store, optionally filters by cwd, and sorts
// newest first.
func listSessions(cwd string) []sessionInfo {
	base, err := transcriptBase()
	if err != nil {
		return nil
	}

	entries, err := os.ReadDir(base)
	if err != nil {
		return nil
	}
	dirs := make([]string, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() {
			dirs = append(dirs, filepath.Join(base, entry.Name()))
		}
	}

	type hit struct {
		info sessionInfo
		at   time.Time
	}
	hitsByID := make(map[string]hit)
	for _, dir := range dirs {
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, entry := range entries {
			name := entry.Name()
			if entry.IsDir() || !strings.HasSuffix(name, ".jsonl") {
				continue
			}
			info, err := entry.Info()
			if err != nil {
				continue
			}
			sessionID := strings.TrimSuffix(name, ".jsonl")
			recordCwd, title := transcriptHead(filepath.Join(dir, name))
			if recordCwd == "" || cwd != "" && !samePath(recordCwd, cwd) {
				continue
			}
			at := info.ModTime().UTC()
			if previous, ok := hitsByID[sessionID]; ok && !at.After(previous.at) {
				continue
			}
			hitsByID[sessionID] = hit{
				info: sessionInfo{
					SessionID: sessionID,
					Cwd:       recordCwd,
					Title:     title,
					UpdatedAt: at.Format(time.RFC3339Nano),
				},
				at: at,
			}
		}
	}

	hits := make([]hit, 0, len(hitsByID))
	for _, item := range hitsByID {
		hits = append(hits, item)
	}
	sort.Slice(hits, func(i, j int) bool {
		if hits[i].at.Equal(hits[j].at) {
			return hits[i].info.SessionID < hits[j].info.SessionID
		}
		return hits[i].at.After(hits[j].at)
	})
	out := make([]sessionInfo, 0, len(hits))
	for _, item := range hits {
		out = append(out, item.info)
	}
	return out
}

// projectSlug mirrors CodeBuddy's transcript directory naming for a cwd.
func projectSlug(cwd string) string {
	var b strings.Builder
	lastDash := true
	for _, r := range cwd {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9':
			b.WriteRune(r)
			lastDash = false
		default:
			if !lastDash {
				b.WriteByte('-')
				lastDash = true
			}
		}
	}
	return strings.Trim(b.String(), "-")
}

// transcriptHead recovers the cwd and first user prompt from a transcript.
func transcriptHead(path string) (string, string) {
	f, err := os.Open(path)
	if err != nil {
		return "", ""
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 64*1024), 1<<20)
	var cwd, title string
	for i := 0; i < headLines && scanner.Scan(); i++ {
		var record struct {
			Type    string `json:"type"`
			Role    string `json:"role"`
			Cwd     string `json:"cwd"`
			Content []struct {
				Text string `json:"text"`
			} `json:"content"`
		}
		if json.Unmarshal(scanner.Bytes(), &record) != nil {
			continue
		}
		if cwd == "" && record.Cwd != "" {
			cwd = record.Cwd
		}
		if title == "" && record.Type == "message" && record.Role == "user" && len(record.Content) > 0 {
			title = truncate(record.Content[0].Text, titleLimit)
		}
		if cwd != "" && title != "" {
			break
		}
	}
	return cwd, title
}

func truncate(s string, n int) string {
	s = strings.TrimSpace(strings.ReplaceAll(s, "\n", " "))
	if len(s) <= n {
		return s
	}
	runes := []rune(s)
	if len(runes) <= n {
		return s
	}
	return strings.TrimSpace(string(runes[:n])) + "…"
}

func samePath(a, b string) bool {
	return filepath.Clean(a) == filepath.Clean(b)
}
