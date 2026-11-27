package main

import (
	"bufio"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"os"
	"os/exec"
	"sync"
)

const listLimit = 200

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
	mu         sync.Mutex
	initID     string
	resumeID   string
	resumeDone bool
	out        *frameWriter
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

func newProxyState(out io.Writer, resumeID string) *proxyState {
	return &proxyState{out: &frameWriter{w: out}, resumeID: resumeID}
}

func serve(real string) error {
	cmd := exec.Command(real)
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
	state := newProxyState(clientOut, os.Getenv("XIAOHUANXIONG_ACP_RESUME_SESSION"))
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
	case "session/new":
		s.mu.Lock()
		resumeID := s.resumeID
		rewrite := resumeID != "" && !s.resumeDone
		if rewrite {
			s.resumeDone = true
		}
		s.mu.Unlock()
		if !rewrite {
			return line
		}
		if rewritten, err := rewriteNewAsLoad(line, resumeID); err == nil {
			return rewritten
		}
		return line
	}
	return line
}

func rewriteNewAsLoad(line []byte, sessionID string) ([]byte, error) {
	var msg map[string]json.RawMessage
	if err := json.Unmarshal(line, &msg); err != nil {
		return nil, err
	}
	if _, ok := msg["id"]; !ok {
		return nil, errors.New("session/new has no id")
	}
	params := map[string]json.RawMessage{}
	if raw, ok := msg["params"]; ok && len(raw) > 0 && string(raw) != "null" {
		if err := json.Unmarshal(raw, &params); err != nil {
			return nil, err
		}
	}
	encoded, err := json.Marshal(sessionID)
	if err != nil {
		return nil, err
	}
	params["sessionId"] = encoded
	rawParams, err := json.Marshal(params)
	if err != nil {
		return nil, err
	}
	msg["method"] = json.RawMessage(`"session/load"`)
	msg["params"] = rawParams
	out, err := json.Marshal(msg)
	if err != nil {
		return nil, err
	}
	return append(out, '\n'), nil
}

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
