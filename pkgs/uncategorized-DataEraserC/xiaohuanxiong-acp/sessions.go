package main

import (
	"bufio"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const (
	headLines  = 40
	titleLimit = 80
)

func agentHome() string {
	if home := os.Getenv("BOX_AGENT_HOME"); home != "" {
		return home
	}
	if os.Getenv("MULTI_INSTANCE") != "" {
		if home, err := os.UserHomeDir(); err == nil {
			return filepath.Join(home, ".box-agent")
		}
		return ""
	}
	base := os.Getenv("XDG_STATE_HOME")
	if base == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return ""
		}
		base = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(base, "xiaohuanxiong-acp", "box-agent")
}

func acpSessionID(uuid string) string {
	return "acp-v1-" + base64.RawURLEncoding.EncodeToString([]byte(uuid))
}

func listSessions(cwd string) []sessionInfo {
	home := agentHome()
	if home == "" {
		return nil
	}
	base := filepath.Join(home, "sessions")
	entries, err := os.ReadDir(base)
	if err != nil {
		return nil
	}

	type hit struct {
		info sessionInfo
		at   time.Time
	}
	hitsByID := make(map[string]hit)
	for _, dir := range entries {
		if !dir.IsDir() {
			continue
		}
		dirPath := filepath.Join(base, dir.Name())
		files, err := os.ReadDir(dirPath)
		if err != nil {
			continue
		}
		for _, entry := range files {
			name := entry.Name()
			if entry.IsDir() || !strings.HasSuffix(name, ".jsonl") {
				continue
			}
			info, err := entry.Info()
			if err != nil {
				continue
			}
			uuid, recordCwd, title := transcriptHead(filepath.Join(dirPath, name))
			if uuid == "" {
				uuid = strings.TrimSuffix(name, ".jsonl")
			}
			if uuid == "" || recordCwd == "" || cwd != "" && !samePath(recordCwd, cwd) {
				continue
			}
			sessionID := acpSessionID(uuid)
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

func transcriptHead(path string) (string, string, string) {
	f, err := os.Open(path)
	if err != nil {
		return "", "", ""
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 64*1024), 1<<20)
	var id, cwd, title string
	for i := 0; i < headLines && scanner.Scan(); i++ {
		var record struct {
			Type string          `json:"type"`
			ID   string          `json:"id"`
			Cwd  string          `json:"cwd"`
			Data json.RawMessage `json:"data"`
		}
		if json.Unmarshal(scanner.Bytes(), &record) != nil {
			continue
		}
		if id == "" && record.Type == "session" && record.ID != "" {
			id = record.ID
		}
		if cwd == "" && record.Cwd != "" {
			cwd = record.Cwd
		}
		if title == "" && record.Type == "user/message" {
			var data struct {
				Role    string          `json:"role"`
				Content json.RawMessage `json:"content"`
			}
			if json.Unmarshal(record.Data, &data) == nil && (data.Role == "" || data.Role == "user") {
				title = truncate(messageText(data.Content), titleLimit)
			}
		}
		if id != "" && cwd != "" && title != "" {
			break
		}
	}
	return id, cwd, title
}

func messageText(raw json.RawMessage) string {
	if len(raw) == 0 {
		return ""
	}
	var text string
	if json.Unmarshal(raw, &text) == nil {
		return text
	}
	var parts []struct {
		Text string `json:"text"`
	}
	if json.Unmarshal(raw, &parts) == nil {
		for _, part := range parts {
			if strings.TrimSpace(part.Text) != "" {
				return part.Text
			}
		}
	}
	return ""
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
