package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	qrcode "github.com/skip2/go-qrcode"
)

const (
	defaultAuthBase = "https://xiaohuanxiong.com/api/web/auth/v1"
	qrLifetime      = 3 * time.Minute
)

type credentials struct {
	accessToken    string
	refreshToken   string
	officeIdentity string
	officeOrgName  string
	officeOrgRole  string
}

type apiEnvelope struct {
	Code    *int            `json:"code"`
	Message string          `json:"message"`
	Msg     string          `json:"msg"`
	Data    json.RawMessage `json:"data"`
}

func authBase() string {
	base := os.Getenv("XIAOHUANXIONG_AUTH_BASE")
	if base == "" {
		base = defaultAuthBase
	}
	return strings.TrimRight(base, "/")
}

func authPath(state localState) string {
	return filepath.Join(state.configDir, "auth.json")
}

func loginQR(state localState) error {
	code, err := newQRCode()
	if err != nil {
		return err
	}
	content := "https://xiaohuanxiong.com/login/mp?code=" + code + "&appname=小浣熊官网"
	qr, err := qrcode.New(content, qrcode.Medium)
	if err != nil {
		return err
	}
	fmt.Println("请使用小浣熊 App 扫描下方二维码登录：")
	fmt.Println(qr.ToSmallString(false))
	fmt.Println("链接：", content)

	ctx := context.Background()
	client := &http.Client{Timeout: 30 * time.Second}
	deadline := time.Now().Add(qrLifetime)
	failures := 0
	for time.Now().Before(deadline) {
		creds, status, expiresAt, err := qrStatus(ctx, client, code)
		if err != nil {
			failures++
			if failures >= 3 {
				return fmt.Errorf("查询扫码状态失败: %w", err)
			}
			time.Sleep(2 * time.Second)
			continue
		}
		failures = 0
		switch status {
		case "success":
			if creds.accessToken == "" {
				return errors.New("扫码登录成功但未返回 access_token")
			}
			if info, err := fetchUserInfo(ctx, client, creds.accessToken); err == nil {
				mergeUserInfo(&creds, info)
			}
			if err := saveAuth(state, creds); err != nil {
				return err
			}
			fmt.Println("登录成功，凭据已写入", authPath(state))
			return nil
		case "pending", "logging":
			if expiresAt > 0 && time.Now().Unix() > normalizedExpiry(expiresAt) {
				return errors.New("二维码已过期，请重新运行 --login")
			}
		case "canceled":
			return errors.New("扫码登录已取消")
		default:
			return fmt.Errorf("扫码登录返回未知状态 %q", status)
		}
		time.Sleep(2 * time.Second)
	}
	return errors.New("扫码登录超时，请重新运行 --login")
}

func newQRCode() (string, error) {
	var nonce [16]byte
	if _, err := rand.Read(nonce[:]); err != nil {
		return "", err
	}
	return fmt.Sprintf("%d%s", time.Now().UnixMilli(), hexString(nonce[:])), nil
}

func hexString(data []byte) string {
	const alphabet = "0123456789abcdef"
	out := make([]byte, len(data)*2)
	for i, b := range data {
		out[i*2] = alphabet[b>>4]
		out[i*2+1] = alphabet[b&0x0f]
	}
	return string(out)
}

func normalizedExpiry(value int64) int64 {
	if value > 1_000_000_000_000 {
		return value / 1000
	}
	return value
}

func qrStatus(ctx context.Context, client *http.Client, code string) (credentials, string, int64, error) {
	body, err := json.Marshal(map[string]string{"qrcode_code": code})
	if err != nil {
		return credentials{}, "", 0, err
	}
	data, err := postAPI(ctx, client, "/login_with_qrcode_code", body, "")
	if err != nil {
		return credentials{}, "", 0, err
	}
	creds := credentialsFromMap(data)
	status := stringField(data, "status")
	return creds, status, int64Field(data, "expired_at"), nil
}

func loginWithCode(state localState, code string) error {
	if strings.TrimSpace(code) == "" {
		return errors.New("授权码不能为空")
	}
	client := &http.Client{Timeout: 30 * time.Second}
	creds, err := exchangeAuthorizationCode(context.Background(), client, code)
	if err != nil {
		return err
	}
	if err := saveAuth(state, creds); err != nil {
		return err
	}
	fmt.Println("登录成功，凭据已写入", authPath(state))
	return nil
}

// exchangeAuthorizationCode trades a one-time web login code for credentials.
// IAM-issued tokens carry no refresh token; saveAuth only stores what came back.
func exchangeAuthorizationCode(ctx context.Context, client *http.Client, code string) (credentials, error) {
	body, err := json.Marshal(map[string]string{"authorization_code": code})
	if err != nil {
		return credentials{}, err
	}
	data, err := postAPI(ctx, client, "/login_with_authorization_code", body, "")
	if err != nil {
		return credentials{}, err
	}
	creds := credentialsFromMap(data)
	if creds.accessToken == "" {
		return credentials{}, errors.New("授权码登录未返回 access_token")
	}
	return creds, nil
}

func fetchUserInfo(ctx context.Context, client *http.Client, accessToken string) (map[string]json.RawMessage, error) {
	endpoint := authBase() + "/user_info"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("user_info HTTP %d", resp.StatusCode)
	}
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	envelope, data, err := decodeEnvelope(raw)
	if err != nil {
		return nil, err
	}
	if envelope.Code != nil && *envelope.Code != 0 {
		return nil, fmt.Errorf("user_info code=%d", *envelope.Code)
	}
	return data, nil
}

func mergeUserInfo(creds *credentials, data map[string]json.RawMessage) {
	if value := stringField(data, "office_identity", "officeIdentity"); value != "" {
		creds.officeIdentity = value
	}
	if value := stringField(data, "office_org_name", "officeOrgName"); value != "" {
		creds.officeOrgName = value
	}
	if value := stringField(data, "office_org_role", "officeOrgRole"); value != "" {
		creds.officeOrgRole = value
	}
}

func postAPI(ctx context.Context, client *http.Client, path string, body []byte, accessToken string) (map[string]json.RawMessage, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, authBase()+path, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if accessToken != "" {
		req.Header.Set("Authorization", "Bearer "+accessToken)
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	envelope, data, err := decodeEnvelope(raw)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("%s HTTP %d: %s", path, resp.StatusCode, envelope.message())
	}
	if envelope.Code != nil && *envelope.Code != 0 {
		return nil, fmt.Errorf("%s code=%d: %s", path, *envelope.Code, envelope.message())
	}
	return data, nil
}

func decodeEnvelope(raw []byte) (apiEnvelope, map[string]json.RawMessage, error) {
	var envelope apiEnvelope
	if err := json.Unmarshal(raw, &envelope); err != nil {
		return apiEnvelope{}, nil, errors.New("账户服务响应无效")
	}
	data := map[string]json.RawMessage{}
	if len(envelope.Data) > 0 && string(envelope.Data) != "null" {
		if err := json.Unmarshal(envelope.Data, &data); err != nil {
			return apiEnvelope{}, nil, errors.New("账户服务响应无效")
		}
	}
	return envelope, data, nil
}

func (e apiEnvelope) message() string {
	for _, value := range []string{e.Message, e.Msg} {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return "请求失败"
}

func credentialsFromMap(data map[string]json.RawMessage) credentials {
	return credentials{
		accessToken:    stringField(data, "access_token", "accessToken", "token", "auth_token"),
		refreshToken:   stringField(data, "refresh_token", "refreshToken"),
		officeIdentity: stringField(data, "office_identity", "officeIdentity"),
		officeOrgName:  stringField(data, "office_org_name", "officeOrgName"),
		officeOrgRole:  stringField(data, "office_org_role", "officeOrgRole"),
	}
}

func stringField(data map[string]json.RawMessage, keys ...string) string {
	for _, key := range keys {
		raw, ok := data[key]
		if !ok {
			continue
		}
		var value string
		if json.Unmarshal(raw, &value) == nil {
			value = strings.TrimSpace(value)
			if value != "" {
				return value
			}
		}
	}
	return ""
}

func int64Field(data map[string]json.RawMessage, key string) int64 {
	raw, ok := data[key]
	if !ok {
		return 0
	}
	var value int64
	if json.Unmarshal(raw, &value) == nil {
		return value
	}
	var text string
	if json.Unmarshal(raw, &text) == nil {
		value, _ := strconv.ParseInt(text, 10, 64)
		return value
	}
	return 0
}

func saveAuth(state localState, creds credentials) error {
	if creds.accessToken == "" {
		return errors.New("access_token 为空，拒绝写入凭据")
	}
	payload := map[string]string{"access_token": creds.accessToken}
	if creds.refreshToken != "" {
		payload["refresh_token"] = creds.refreshToken
	}
	for key, value := range map[string]string{
		"office_identity": creds.officeIdentity,
		"office_org_name": creds.officeOrgName,
		"office_org_role": creds.officeOrgRole,
	} {
		if value != "" {
			payload[key] = value
		}
	}

	encoded, err := json.MarshalIndent(payload, "", "  ")
	if err != nil {
		return err
	}
	encoded = append(encoded, '\n')

	dir := state.configDir
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	temp, err := os.CreateTemp(dir, ".auth-*.tmp")
	if err != nil {
		return err
	}
	tempName := temp.Name()
	defer os.Remove(tempName)
	if err := temp.Chmod(0o600); err != nil {
		temp.Close()
		return err
	}
	if _, err := temp.Write(encoded); err != nil {
		temp.Close()
		return err
	}
	if err := temp.Close(); err != nil {
		return err
	}
	if err := os.Rename(tempName, authPath(state)); err != nil {
		return err
	}
	return nil
}
