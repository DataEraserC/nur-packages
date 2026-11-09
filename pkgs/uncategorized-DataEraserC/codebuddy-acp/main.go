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
// Without --acp the proxy execs the real binary, so the TUI and --print behave
// exactly as before.
package main

import (
	"bufio"
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

var (
	outMu    sync.Mutex
	initID   string
	initSeen bool
)

// version is the proxy's own version, set at build time. The wrapped CLI keeps
// its own version: only --acp-proxy-version is answered here.
var version = "dev"

func main() {
	for _, arg := range os.Args[1:] {
		if arg == "--acp-proxy-version" {
			fmt.Println(version)
			return
		}
	}
	args := os.Args[1:]
	real, err := realBinary()
	if err != nil {
		fmt.Fprintln(os.Stderr, "codebuddy-acp:", err)
		os.Exit(2)
	}
	if !acpStdio(args) {
		if err := syscall.Exec(real, append([]string{real}, args...), os.Environ()); err != nil {
			fmt.Fprintln(os.Stderr, "codebuddy-acp: exec:", err)
			os.Exit(2)
		}
		return
	}
	if err := serve(real, args); err != nil {
		fmt.Fprintln(os.Stderr, "codebuddy-acp:", err)
		os.Exit(1)
	}
}

// acpStdio reports whether these arguments select the stdio ACP server, the
// only transport a line proxy can sit in front of.
func acpStdio(args []string) bool {
	acp := false
	for i := 0; i < len(args); i++ {
		switch {
		case args[i] == "--acp":
			acp = true
		case args[i] == "--acp-transport" && i+1 < len(args):
			return acp && args[i+1] == "stdio"
		case strings.HasPrefix(args[i], "--acp-transport="):
			return acp && strings.TrimPrefix(args[i], "--acp-transport=") == "stdio"
		}
	}
	return acp
}

// realBinary locates the wrapped CLI: the explicit override first, then the
// first codebuddy/cbc on PATH that is not this proxy.
func realBinary() (string, error) {
	if p := os.Getenv("CODEBUDDY_ACP_REAL"); p != "" {
		return p, nil
	}
	self, _ := os.Executable()
	for _, dir := range filepath.SplitList(os.Getenv("PATH")) {
		for _, name := range []string{"codebuddy", "cbc"} {
			candidate := filepath.Join(dir, name)
			info, err := os.Stat(candidate)
			if err != nil || info.IsDir() || info.Mode()&0o111 == 0 {
				continue
			}
			if resolved, err := filepath.EvalSymlinks(candidate); err == nil && resolved == self {
				continue
			}
			return candidate, nil
		}
	}
	return "", errors.New("cannot find the codebuddy binary to wrap (set CODEBUDDY_ACP_REAL)")
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

	done := make(chan struct{})
	go func() {
		defer close(done)
		forward(os.Stdin, stdin, interceptClient)
		stdin.Close()
	}()
	forward(stdout, os.Stdout, rewriteServer)
	<-done
	return cmd.Wait()
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
	if _, err := dst.Write(p); err != nil {
		return
	}
}

// interceptClient drops session/list (answered locally) and remembers the
// initialize id so its response can be patched. Every other frame passes.
func interceptClient(line []byte) []byte {
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
		initID = string(msg.ID)
		return line
	case "session/list":
		answer := listAnswer(msg.ID, msg.Params.Cwd, msg.Params.Cursor)
		outMu.Lock()
		defer outMu.Unlock()
		os.Stdout.Write(answer)
		return nil
	}
	return line
}

// rewriteServer injects the session/list capability into the initialize
// response and passes everything else through untouched.
func rewriteServer(line []byte) []byte {
	if initID == "" {
		return line
	}
	var msg map[string]json.RawMessage
	if json.Unmarshal(line, &msg) != nil {
		return line
	}
	id, ok := msg["id"]
	if !ok || string(id) != initID {
		return line
	}
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
	rawCaps, ok := res["agentCapabilities"]
	if !ok {
		return nil, errors.New("initialize result has no agentCapabilities")
	}
	var caps map[string]json.RawMessage
	if err := json.Unmarshal(rawCaps, &caps); err != nil {
		return nil, err
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

// listAnswer builds a session/list response from CodeBuddy's transcripts.
func listAnswer(id json.RawMessage, cwd, cursor string) []byte {
	if cwd == "" {
		cwd, _ = os.Getwd()
	}
	sessions := listSessions(cwd)
	resp := map[string]json.RawMessage{
		"jsonrpc": json.RawMessage(`"2.0"`),
		"id":      id,
	}
	body, err := json.Marshal(listResponse{Sessions: sessions})
	if err != nil {
		errFrame := fmt.Sprintf(`{"jsonrpc":"2.0","id":%s,"error":{"code":-32603,"message":"session/list failed"}}`+"\n", id)
		return []byte(errFrame)
	}
	resp["result"] = body
	out, err := json.Marshal(resp)
	if err != nil {
		return []byte(fmt.Sprintf(`{"jsonrpc":"2.0","id":%s,"result":{"sessions":[]}}`+"\n", id))
	}
	return append(out, '\n')
}

// transcriptBase is CodeBuddy's transcript root. The CLI stores transcripts in
// $CODEBUDDY_CONFIG_DIR/projects when an isolated profile exists there, and in
// ~/.codebuddy/projects otherwise, so both are tried.
func transcriptBase() (string, error) {
	if dir := os.Getenv("CODEBUDDY_CONFIG_DIR"); dir != "" {
		path := filepath.Join(dir, "projects")
		if info, err := os.Stat(path); err == nil && info.IsDir() {
			return path, nil
		}
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".codebuddy", "projects"), nil
}

// listSessions reads the transcript store for cwd, newest first.
func listSessions(cwd string) []sessionInfo {
	base, err := transcriptBase()
	if err != nil {
		return nil
	}
	dirs := []string{filepath.Join(base, projectSlug(cwd))}
	if _, err := os.Stat(dirs[0]); err != nil {
		entries, readErr := os.ReadDir(base)
		if readErr != nil {
			return nil
		}
		for _, e := range entries {
			if e.IsDir() {
				dirs = append(dirs, filepath.Join(base, e.Name()))
			}
		}
	}

	type hit struct {
		info sessionInfo
		at   time.Time
	}
	var hits []hit
	seen := map[string]bool{}
	for _, dir := range dirs {
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, e := range entries {
			name := e.Name()
			if e.IsDir() || !strings.HasSuffix(name, ".jsonl") {
				continue
			}
			sid := strings.TrimSuffix(name, ".jsonl")
			if seen[sid] {
				continue
			}
			info, err := e.Info()
			if err != nil {
				continue
			}
			path := filepath.Join(dir, name)
			recordCwd, title := transcriptHead(path)
			if recordCwd != "" && !samePath(recordCwd, cwd) {
				continue
			}
			seen[sid] = true
			at := info.ModTime().UTC()
			hits = append(hits, hit{
				info: sessionInfo{
					SessionID: sid,
					Cwd:       cwd,
					Title:     title,
					UpdatedAt: at.Format(time.RFC3339Nano),
				},
				at: at,
			})
		}
	}
	sort.Slice(hits, func(i, j int) bool { return hits[i].at.After(hits[j].at) })
	if len(hits) > listLimit {
		hits = hits[:listLimit]
	}
	out := make([]sessionInfo, 0, len(hits))
	for _, h := range hits {
		out = append(out, h.info)
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
