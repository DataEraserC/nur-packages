package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"
)

var (
	version         = "dev"
	defaultBoxAgent string
	defaultMartty   string
)

const defaultConfig = `api_key: "box-agent-no-auth"
api_base: "https://xiaohuanxiong.com/api/web/llm/v2"
model: "sn-qwen4-max"
provider: "openai"
context_window: 1000000
max_output_tokens: 100000
enable_memory: false
enable_memory_extraction: false
`

type localState struct {
	agentHome  string
	configDir  string
	marttyHome string
}

func main() {
	args := os.Args[1:]
	if strings.HasSuffix(filepath.Base(os.Args[0]), "-resume") {
		args = append([]string{"--resume"}, args...)
	}
	if len(args) == 1 {
		switch args[0] {
		case "--acp-proxy-version":
			fmt.Println(version)
			return
		case "--version", "-V":
			fmt.Printf("xiaohuanxiong-acp %s\n", version)
			return
		case "--help", "-h":
			usage()
			return
		}
	}

	state, err := prepareState()
	if err != nil {
		fatal(err)
	}
	if len(args) > 0 {
		switch args[0] {
		case "--login":
			if err := loginQR(state); err != nil {
				fatal(err)
			}
			return
		case "--login-code":
			if len(args) != 2 {
				fatal(errors.New("usage: xiaohuanxiong-acp --login-code <authorization-code>"))
			}
			if err := loginWithCode(state, args[1]); err != nil {
				fatal(err)
			}
			return
		case "--acp":
			resumeID, rest, err := takeResume(args[1:])
			if err != nil {
				fatal(err)
			}
			if err := serveACP(state, resumeID, rest); err != nil {
				fatal(err)
			}
			return
		case "--resume":
			if len(args) < 2 {
				fatal(errors.New("usage: xiaohuanxiong-acp --resume <session-id> [-- <tui args>]"))
			}
			if err := runTUI(state, args[1], args[2:]); err != nil {
				fatal(err)
			}
			return
		}
	}
	resumeID, rest, err := takeResume(args)
	if err != nil {
		fatal(err)
	}
	if err := runTUI(state, resumeID, rest); err != nil {
		fatal(err)
	}
}

func usage() {
	fmt.Println(`xiaohuanxiong-acp — terminal and ACP client for the Raccoon Work agent

USAGE:
  xiaohuanxiong-acp                 open the terminal UI
  xiaohuanxiong-acp --resume <id>   resume a Raccoon session in the terminal UI
  xiaohuanxiong-acp --acp           speak ACP over stdio (used by WebMux)
  xiaohuanxiong-acp --login         log in by scanning a QR code
  xiaohuanxiong-acp --login-code <code>
                                    log in with a web authorization code
  xiaohuanxiong-acp --version       print the version
  xiaohuanxiong-acp --help          print this help

STATE:
  Multi-instance runs keep state under the instance HOME (~/.box-agent).
  Direct runs keep state under $XDG_STATE_HOME/xiaohuanxiong-acp, or
  ~/.local/state/xiaohuanxiong-acp, independent from the desktop client.
  BOX_AGENT_HOME and MARTTY_HOME override the locations.`)
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "xiaohuanxiong-acp:", err)
	os.Exit(2)
}

func prepareState() (localState, error) {
	agentHome := os.Getenv("BOX_AGENT_HOME")
	if agentHome == "" {
		if os.Getenv("MULTI_INSTANCE") != "" {
			home, err := os.UserHomeDir()
			if err != nil {
				return localState{}, err
			}
			agentHome = filepath.Join(home, ".box-agent")
		} else {
			base := os.Getenv("XDG_STATE_HOME")
			if base == "" {
				home, err := os.UserHomeDir()
				if err != nil {
					return localState{}, err
				}
				base = filepath.Join(home, ".local", "state")
			}
			agentHome = filepath.Join(base, "xiaohuanxiong-acp", "box-agent")
		}
	}

	configDir := os.Getenv("BOX_AGENT_CONFIG_DIR")
	if configDir == "" {
		configDir = filepath.Join(agentHome, "config")
	}
	marttyHome := os.Getenv("MARTTY_HOME")
	if marttyHome == "" {
		marttyHome = filepath.Join(agentHome, "martty")
	}

	state := localState{agentHome: agentHome, configDir: configDir, marttyHome: marttyHome}
	for _, dir := range []string{state.agentHome, state.configDir, state.marttyHome} {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			return localState{}, err
		}
	}
	if err := seedConfig(state.configDir); err != nil {
		return localState{}, err
	}
	return state, nil
}

func seedConfig(configDir string) error {
	path := filepath.Join(configDir, "config.yaml")
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if errors.Is(err, os.ErrExist) {
		return nil
	}
	if err != nil {
		return err
	}
	if _, err := file.WriteString(defaultConfig); err != nil {
		file.Close()
		return err
	}
	return file.Close()
}

func takeResume(args []string) (string, []string, error) {
	rest := make([]string, 0, len(args))
	resumeID := ""
	for i := 0; i < len(args); i++ {
		if args[i] != "--resume" {
			rest = append(rest, args[i])
			continue
		}
		if i+1 >= len(args) {
			return "", nil, errors.New("--resume requires a session id")
		}
		if resumeID != "" {
			return "", nil, errors.New("--resume may only be given once")
		}
		resumeID = args[i+1]
		i++
	}
	return resumeID, rest, nil
}

func agentBinary() (string, error) {
	if path := os.Getenv("XIAOHUANXIONG_ACP_REAL"); path != "" {
		return path, nil
	}
	if defaultBoxAgent != "" {
		return defaultBoxAgent, nil
	}
	return "", errors.New("box-agent binary is not configured (set XIAOHUANXIONG_ACP_REAL)")
}

func marttyBinary() (string, error) {
	if path := os.Getenv("XIAOHUANXIONG_ACP_MARTTY"); path != "" {
		return path, nil
	}
	if defaultMartty != "" {
		return defaultMartty, nil
	}
	return "", errors.New("Martty binary is not configured (set XIAOHUANXIONG_ACP_MARTTY)")
}

func runTUI(state localState, resumeID string, args []string) error {
	martty, err := marttyBinary()
	if err != nil {
		return err
	}
	self, err := os.Executable()
	if err != nil {
		return err
	}
	argv := []string{
		martty,
		"--agent", self,
		"--agent-arg", "--acp",
		"--session-root", filepath.Join(state.marttyHome, "sessions"),
	}
	if resumeID != "" {
		argv = append(argv, "--session-id", resumeID)
	}
	argv = append(argv, args...)

	env := withEnv(os.Environ(), "BOX_AGENT_HOME", state.agentHome)
	env = withEnv(env, "BOX_AGENT_CONFIG_DIR", state.configDir)
	env = withEnv(env, "MARTTY_HOME", state.marttyHome)
	env = withEnv(env, "NODE_ENV", "production")
	if resumeID != "" {
		env = withEnv(env, "XIAOHUANXIONG_ACP_RESUME_SESSION", resumeID)
	}
	return syscall.Exec(martty, argv, env)
}

func withEnv(env []string, key, value string) []string {
	prefix := key + "="
	out := make([]string, 0, len(env)+1)
	for _, item := range env {
		if !strings.HasPrefix(item, prefix) {
			out = append(out, item)
		}
	}
	return append(out, prefix+value)
}

func serveACP(state localState, resumeID string, args []string) error {
	real, err := agentBinary()
	if err != nil {
		return err
	}
	if len(args) > 0 {
		return fmt.Errorf("unexpected arguments after --acp: %s", strings.Join(args, " "))
	}
	if resumeID != "" {
		if err := os.Setenv("XIAOHUANXIONG_ACP_RESUME_SESSION", resumeID); err != nil {
			return err
		}
	}
	if err := os.Setenv("BOX_AGENT_HOME", state.agentHome); err != nil {
		return err
	}
	if err := os.Setenv("BOX_AGENT_CONFIG_DIR", state.configDir); err != nil {
		return err
	}
	return serve(real)
}
