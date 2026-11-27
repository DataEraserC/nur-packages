package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Model selection for the ACP chat. box-agent has no session/set_config_option
// and no config options of its own, but it honours the desktop client's
// per-prompt `_meta.llm_binding` extension. The proxy publishes a standard ACP
// "model" option, remembers the choice per session, and injects the binding on
// each prompt. The catalog comes from the account gateway, which needs the
// login token from auth.json.

const (
	catalogPath           = "/api/web/llm/v2/model_catalog"
	catalogFreshFor       = time.Hour
	catalogRetryAfter     = time.Minute
	catalogFetchTimeout   = 4 * time.Second
	modelOptionID         = "model"
	maxCatalogModels      = 100
	maxSelectionEntries   = 200
	catalogCacheFileName  = "model-catalog-cache.json"
	selectionFileName     = "model-selection.json"
	defaultContextWindow  = 1_000_000
	defaultMaxOutputToken = 100_000
)

type catalogModel struct {
	ID            string `json:"id"`
	Name          string `json:"name"`
	Description   string `json:"description,omitempty"`
	ContextWindow int    `json:"contextWindow,omitempty"`
	MaxTokens     int    `json:"maxTokens,omitempty"`
}

type catalogCache struct {
	FetchedAt int64          `json:"fetchedAt"`
	Models    []catalogModel `json:"models"`
}

type modelSelection struct {
	Model         string `json:"model"`
	ContextWindow int    `json:"contextWindow,omitempty"`
	MaxTokens     int    `json:"maxTokens,omitempty"`
}

type modelStore struct {
	mu sync.Mutex

	configDir string
	origin    string
	client    *http.Client

	defaultModel    string
	contextWindow   int
	maxOutputTokens int

	catalog   []catalogModel
	catalogAt time.Time
	lastTry   time.Time
	selection map[string]modelSelection
}

func newModelStore(configDir string) *modelStore {
	store := &modelStore{
		configDir:       configDir,
		origin:          modelOrigin(),
		client:          &http.Client{Timeout: catalogFetchTimeout},
		defaultModel:    defaultContextWindowModel(configDir),
		contextWindow:   configInt(configDir, "context_window", defaultContextWindow),
		maxOutputTokens: configInt(configDir, "max_output_tokens", defaultMaxOutputToken),
		selection:       map[string]modelSelection{},
	}
	store.loadCache()
	store.loadSelection()
	return store
}

func modelOrigin() string {
	origin := os.Getenv("XIAOHUANXIONG_LLM_ORIGIN")
	if origin == "" {
		origin = loginBase()
	}
	return strings.TrimRight(origin, "/")
}

// defaultContextWindowModel reads the model configured for the runtime, which
// is the value the agent uses when no binding is injected.
func defaultContextWindowModel(configDir string) string {
	if value := configString(configDir, "model"); value != "" {
		return value
	}
	return "raccoon-090dd3"
}

func configString(configDir, key string) string {
	raw, err := os.ReadFile(filepath.Join(configDir, "config.yaml"))
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		rest, ok := strings.CutPrefix(line, key+":")
		if !ok {
			continue
		}
		return strings.Trim(strings.TrimSpace(rest), `"'`)
	}
	return ""
}

func configInt(configDir, key string, fallback int) int {
	value, err := strconv.Atoi(configString(configDir, key))
	if err != nil || value <= 0 {
		return fallback
	}
	return value
}

func (s *modelStore) loadCache() {
	raw, err := os.ReadFile(filepath.Join(s.configDir, catalogCacheFileName))
	if err != nil {
		return
	}
	var cache catalogCache
	if json.Unmarshal(raw, &cache) != nil || len(cache.Models) == 0 {
		return
	}
	s.catalog = cache.Models
	s.catalogAt = time.Unix(cache.FetchedAt, 0)
}

func (s *modelStore) loadSelection() {
	raw, err := os.ReadFile(filepath.Join(s.configDir, selectionFileName))
	if err != nil {
		return
	}
	var selection map[string]modelSelection
	if json.Unmarshal(raw, &selection) != nil {
		return
	}
	for id, value := range selection {
		if id != "" && value.Model != "" {
			s.selection[id] = value
		}
	}
}

func (s *modelStore) saveSelectionLocked() {
	if len(s.selection) > maxSelectionEntries {
		// Old entries only matter while their session can be resumed; keep the
		// file bounded by dropping arbitrary entries down to half the cap.
		for id := range s.selection {
			delete(s.selection, id)
			if len(s.selection) <= maxSelectionEntries/2 {
				break
			}
		}
	}
	encoded, err := json.MarshalIndent(s.selection, "", "  ")
	if err != nil {
		return
	}
	atomicWrite(filepath.Join(s.configDir, selectionFileName), append(encoded, '\n'))
}

func (s *modelStore) saveCacheLocked() {
	encoded, err := json.Marshal(catalogCache{FetchedAt: s.catalogAt.Unix(), Models: s.catalog})
	if err != nil {
		return
	}
	atomicWrite(filepath.Join(s.configDir, catalogCacheFileName), append(encoded, '\n'))
}

func atomicWrite(path string, data []byte) {
	temp, err := os.CreateTemp(filepath.Dir(path), ".tmp-*")
	if err != nil {
		return
	}
	name := temp.Name()
	defer os.Remove(name)
	if temp.Chmod(0o600) != nil {
		temp.Close()
		return
	}
	if _, err := temp.Write(data); err != nil {
		temp.Close()
		return
	}
	if err := temp.Close(); err != nil {
		return
	}
	_ = os.Rename(name, path)
}

func (s *modelStore) accessToken() string {
	raw, err := os.ReadFile(authPath(localState{configDir: s.configDir}))
	if err != nil {
		return ""
	}
	var payload struct {
		AccessToken string `json:"access_token"`
	}
	if json.Unmarshal(raw, &payload) != nil {
		return ""
	}
	return strings.TrimSpace(payload.AccessToken)
}

// models returns the cached catalog, refreshing it when stale. Failures leave
// the previous list in place and are retried at most once a minute.
func (s *modelStore) models() []catalogModel {
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.catalog) > 0 && time.Since(s.catalogAt) < catalogFreshFor {
		return append([]catalogModel(nil), s.catalog...)
	}
	if !s.lastTry.IsZero() && time.Since(s.lastTry) < catalogRetryAfter {
		return append([]catalogModel(nil), s.catalog...)
	}
	s.lastTry = time.Now()
	token := s.accessToken()
	if token == "" {
		return append([]catalogModel(nil), s.catalog...)
	}
	catalog, err := s.fetchCatalog(token)
	if err != nil || len(catalog) == 0 {
		return append([]catalogModel(nil), s.catalog...)
	}
	s.catalog = catalog
	s.catalogAt = time.Now()
	s.saveCacheLocked()
	return append([]catalogModel(nil), s.catalog...)
}

func (s *modelStore) fetchCatalog(token string) ([]catalogModel, error) {
	request, err := http.NewRequest(http.MethodGet, s.origin+catalogPath, nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("Authorization", "Bearer "+token)
	response, err := s.client.Do(request)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("model catalog HTTP %d", response.StatusCode)
	}
	raw, err := io.ReadAll(io.LimitReader(response.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	return parseCatalog(raw)
}

func parseCatalog(raw []byte) ([]catalogModel, error) {
	var envelope struct {
		Code *int `json:"code"`
		Data struct {
			Categories []struct {
				Type   string `json:"type"`
				Models []struct {
					Name   string   `json:"name"`
					Model  string   `json:"model_name"`
					Desc   string   `json:"description"`
					Tags   []string `json:"tags"`
					Params struct {
						ContextWindow int `json:"context_window"`
						MaxTokens     int `json:"max_output_tokens"`
					} `json:"params"`
				} `json:"models"`
			} `json:"categories"`
		} `json:"data"`
	}
	if err := json.Unmarshal(raw, &envelope); err != nil {
		return nil, err
	}
	if envelope.Code != nil && *envelope.Code != 0 {
		return nil, errors.New("model catalog rejected")
	}
	models := make([]catalogModel, 0, 32)
	seen := map[string]bool{}
	for _, category := range envelope.Data.Categories {
		if category.Type != "chat" {
			continue
		}
		for _, item := range category.Models {
			id := strings.TrimSpace(item.Model)
			if id == "" {
				id = strings.TrimSpace(item.Name)
			}
			if id == "" || seen[id] || len(models) >= maxCatalogModels {
				continue
			}
			seen[id] = true
			description := strings.TrimSpace(item.Desc)
			if description == "" && len(item.Tags) > 0 {
				description = strings.Join(item.Tags, ", ")
			}
			if len(description) > 160 {
				description = description[:160]
			}
			models = append(models, catalogModel{
				ID:            id,
				Name:          firstNonEmpty(strings.TrimSpace(item.Name), id),
				Description:   description,
				ContextWindow: item.Params.ContextWindow,
				MaxTokens:     item.Params.MaxTokens,
			})
		}
	}
	return models, nil
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return ""
}

func (s *modelStore) selected(sessionID string) (modelSelection, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	selection, ok := s.selection[sessionID]
	return selection, ok && selection.Model != ""
}

func (s *modelStore) selectModel(sessionID, model string) (modelSelection, bool) {
	models := s.models()
	if model == "" {
		return modelSelection{}, false
	}
	found := false
	for _, candidate := range models {
		if candidate.ID == model {
			found = true
			break
		}
	}
	if !found && model != s.defaultModel {
		return modelSelection{}, false
	}
	selection := modelSelection{Model: model}
	for _, candidate := range models {
		if candidate.ID == model {
			selection.ContextWindow = candidate.ContextWindow
			selection.MaxTokens = candidate.MaxTokens
			break
		}
	}
	if selection.ContextWindow <= 0 {
		selection.ContextWindow = s.contextWindow
	}
	if selection.MaxTokens <= 0 {
		selection.MaxTokens = s.maxOutputTokens
	}
	s.mu.Lock()
	s.selection[sessionID] = selection
	s.saveSelectionLocked()
	s.mu.Unlock()
	return selection, true
}

// binding returns the per-prompt llm_binding for a session that chose a model.
func (s *modelStore) binding(sessionID string) map[string]any {
	selection, ok := s.selected(sessionID)
	if !ok {
		return nil
	}
	return map[string]any{
		"source":        "builtin",
		"model":         selection.Model,
		"contextWindow": selection.ContextWindow,
		"maxTokens":     selection.MaxTokens,
	}
}

type selectOption struct {
	Value       string `json:"value"`
	Name        string `json:"name"`
	Description string `json:"description,omitempty"`
}

type configOption struct {
	ID           string         `json:"id"`
	Name         string         `json:"name"`
	Description  string         `json:"description,omitempty"`
	Category     string         `json:"category,omitempty"`
	Type         string         `json:"type"`
	CurrentValue string         `json:"currentValue"`
	Options      []selectOption `json:"options"`
}

// configOptions publishes the model picker. The current value is the session's
// saved choice, or the runtime's configured model before any choice is made.
func (s *modelStore) configOptions(sessionID string) []configOption {
	current := s.defaultModel
	if selection, ok := s.selected(sessionID); ok {
		current = selection.Model
	}
	models := s.models()
	options := make([]selectOption, 0, len(models)+1)
	seen := map[string]bool{}
	for _, model := range models {
		if seen[model.ID] {
			continue
		}
		seen[model.ID] = true
		options = append(options, selectOption{Value: model.ID, Name: model.Name, Description: model.Description})
	}
	if !seen[current] {
		options = append([]selectOption{{Value: current, Name: current}}, options...)
	}
	return []configOption{{
		ID:           modelOptionID,
		Name:         "Model",
		Description:  "Model used for the next turn",
		Category:     "model",
		Type:         "select",
		CurrentValue: current,
		Options:      options,
	}}
}
