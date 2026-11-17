{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dataEraserc.workbuddy2api;
  inherit (lib) mkOption types;

  jsonFormat = pkgs.formats.json { };
  inherit (cfg) stateDir;
  configPath = "${stateDir}/config.json";
  generatedApiKeyPath = "${stateDir}/api-key";
  useStateDirectory = builtins.dirOf stateDir == "/var/lib";
  serverExecutable =
    if cfg.package != null then lib.getExe cfg.package else "${pkgs.coreutils}/bin/false";

  setting =
    type: default: description:
    mkOption { inherit type default description; };
  sectionType =
    options:
    types.submodule {
      freeformType = jsonFormat.type;
      inherit options;
    };
  sectionOption =
    description: options:
    mkOption {
      type = sectionType options;
      default = { };
      inherit description;
    };
  envOption =
    type: description:
    mkOption {
      type = types.nullOr type;
      default = null;
      inherit description;
    };
  envString = envOption types.str;
  envInt = envOption types.int;
  envBool = envOption types.bool;
  hoursType = types.listOf (types.ints.between 0 23);

  settingsWithoutManaged = builtins.removeAttrs cfg.settings [
    "listen"
    "api_key"
    "auth_dir"
    "state_file"
  ];
  managedSettingKeys = builtins.filter (key: builtins.hasAttr key cfg.settings) [
    "listen"
    "api_key"
    "auth_dir"
    "state_file"
  ];
  secretSettingKeys =
    lib.optional (builtins.hasAttr "device_token" cfg.settings.upstream) "upstream.device_token"
    ++ lib.optional (builtins.hasAttr "token" cfg.settings.upstash) "upstash.token";
  renderedSettings = settingsWithoutManaged // {
    listen =
      if cfg.listenAddress == "" then
        ":${toString cfg.port}"
      else
        "${cfg.listenAddress}:${toString cfg.port}";
    api_key = "";
    auth_dir = cfg.authDir;
    state_file = cfg.stateFile;
    upstream = builtins.removeAttrs cfg.settings.upstream [ "device_token" ];
    upstash = (builtins.removeAttrs cfg.settings.upstash [ "token" ]) // {
      token = "";
    };
    trae = cfg.settings.trae // {
      data_dir =
        if cfg.settings.trae.data_dir == "" then "${stateDir}/trae" else cfg.settings.trae.data_dir;
    };
  };
  generatedConfig = jsonFormat.generate "workbuddy2api-config.json" renderedSettings;
  configFingerprint = builtins.hashString "sha256" (builtins.toJSON renderedSettings);

  filteredEnvironment = lib.filterAttrs (_: value: value != null) cfg.environment;
  providerStateEnvironment = {
    HOME = stateDir;
    XDG_CONFIG_HOME = "${stateDir}/.config";
    IDEAUTH_AUTH_DIR = cfg.authDir;
    IDEAUTH_POOL_DIR = "${stateDir}/data/ide_accounts";
    QODER_DATA_DIR = "${stateDir}/.config/com.qoder.app.stable";
    QODER_PROBE_FILE = "${stateDir}/data/qoder_identity_probe.json";
    QODER_EGRESS_FILE = "${stateDir}/data/ide_accounts/qoder_egress.json";
    TRAE_DATA_DIR = renderedSettings.trae.data_dir;
    MINIMAX_POOL_FILE = "${stateDir}/data/minimax_accounts.json";
    CODEARTS_POOL_FILE = "${stateDir}/data/ide_accounts/codearts_accounts.json";
    CODEARTS_SLOT_ROOT = "${stateDir}/data/ide_accounts/codearts-slots";
    DOUBAO_POOL_FILE = "${stateDir}/data/doubao_accounts.json";
  };
  managedEnvironment =
    providerStateEnvironment
    // filteredEnvironment
    // {
      WB2A_LISTEN = renderedSettings.listen;
      WB2A_AUTH_DIR = cfg.authDir;
      WB2A_STATE_FILE = cfg.stateFile;
    };
  serviceEnvironment = lib.mapAttrs (
    _: value: if builtins.isBool value then lib.boolToString value else toString value
  ) managedEnvironment;

  prepareConfig = pkgs.writeShellScript "workbuddy2api-prepare-config" ''
    set -eu
    umask 077

    ${pkgs.coreutils}/bin/install -d -m 0700 \
      ${lib.escapeShellArg stateDir} \
      ${lib.escapeShellArg cfg.authDir} \
      ${lib.escapeShellArg (builtins.dirOf cfg.stateFile)} \
      ${lib.escapeShellArg "${stateDir}/data/ide_accounts"} \
      ${lib.escapeShellArg "${stateDir}/.config/com.qoder.app.stable"} \
      ${lib.escapeShellArg renderedSettings.trae.data_dir}

    config=${lib.escapeShellArg configPath}
    marker=${lib.escapeShellArg "${stateDir}/.config-source"}
    previous="$(${pkgs.coreutils}/bin/cat "$marker" 2>/dev/null || true)"
    refresh=0
    record_marker=0
    case ${lib.escapeShellArg cfg.configMode} in
      seed-only)
        if [ ! -s "$config" ]; then
          refresh=1
        elif [ -z "$previous" ]; then
          record_marker=1
        elif [ "$previous" != ${lib.escapeShellArg configFingerprint} ]; then
          echo "workbuddy2api: declared settings changed, but configMode=seed-only preserves panel edits; select on-change or overwrite to apply them" >&2
        fi
        ;;
      on-change)
        if [ ! -s "$config" ] || [ "$previous" != ${lib.escapeShellArg configFingerprint} ]; then
          refresh=1
        fi
        ;;
      overwrite)
        refresh=1
        ;;
    esac

    if [ "$refresh" -eq 1 ]; then
      ${pkgs.coreutils}/bin/install -m 0600 ${generatedConfig} "$config.new"
      ${pkgs.coreutils}/bin/mv -f "$config.new" "$config"
      record_marker=1
    fi
    if [ "$record_marker" -eq 1 ]; then
      ${pkgs.coreutils}/bin/rm -f "$marker"
      printf '%s\n' ${lib.escapeShellArg configFingerprint} > "$marker"
      chmod 0600 "$marker"
    fi

    ${lib.optionalString (cfg.apiKeyFile == null && cfg.enableGeneratedApiKey) ''
      api_key_path=${lib.escapeShellArg generatedApiKeyPath}
      if [ ! -s "$api_key_path" ]; then
        ${pkgs.coreutils}/bin/rm -f "$api_key_path"
        printf 'sk-%s\n' "$(
          ${pkgs.coreutils}/bin/head -c 24 /dev/urandom | ${pkgs.coreutils}/bin/od -An -tx1 | ${pkgs.coreutils}/bin/tr -d ' \n'
        )" > "$api_key_path"
        chmod 0600 "$api_key_path"
      fi
    ''}

    ${lib.optionalString (cfg.upstashTokenFile != null) ''
      if [ -s "$CREDENTIALS_DIRECTORY/upstash-token" ]; then
        ${lib.getExe pkgs.jq} --rawfile token "$CREDENTIALS_DIRECTORY/upstash-token" \
          '.upstash.token = ($token | sub("[\\r\\n]+$"; ""))' \
          "$config" > "$config.new"
        chmod 0600 "$config.new"
        ${pkgs.coreutils}/bin/mv -f "$config.new" "$config"
      fi
    ''}
  '';

  startScript = pkgs.writeShellScript "workbuddy2api-start" ''
    set -eu
    export WB2A_LISTEN=${lib.escapeShellArg renderedSettings.listen}
    export WB2A_AUTH_DIR=${lib.escapeShellArg cfg.authDir}
    export WB2A_STATE_FILE=${lib.escapeShellArg cfg.stateFile}
    ${lib.optionalString (cfg.apiKeyFile != null) ''
      if [ -s "$CREDENTIALS_DIRECTORY/api-key" ]; then
        WB2A_API_KEY="$(${pkgs.coreutils}/bin/cat "$CREDENTIALS_DIRECTORY/api-key")"
        export WB2A_API_KEY
      fi
    ''}
    ${lib.optionalString
      (cfg.apiKeyFile == null && cfg.enableGeneratedApiKey && cfg.environment.WB2A_API_KEY == null)
      ''
        if [ -s ${lib.escapeShellArg generatedApiKeyPath} ]; then
          WB2A_API_KEY="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg generatedApiKeyPath})"
          export WB2A_API_KEY
        fi
      ''
    }
    ${lib.optionalString (cfg.deviceTokenFile != null) ''
      export WB2A_DEVICE_TOKEN_FILE="$CREDENTIALS_DIRECTORY/device-token"
    ''}
    exec ${serverExecutable} -config ${lib.escapeShellArg configPath}
  '';
in
{
  options.services.dataEraserc.workbuddy2api = {
    enable = lib.mkEnableOption "the WorkBuddy2API multi-provider gateway and panel";

    package = mkOption {
      type = types.nullOr types.package;
      default = pkgs.workbuddy2api-panel or null;
      description = ''
        WorkBuddy2API panel package to run. The default is available when the
        repository overlay exposes <literal>pkgs.workbuddy2api-panel</literal>.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "workbuddy2api";
      description = "User account under which the service runs. The default account is created automatically.";
    };

    group = mkOption {
      type = types.str;
      default = "workbuddy2api";
      description = "Group under which the service runs. The default group is created automatically.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/workbuddy2api";
      description = ''
        Writable service root containing the mutable panel configuration,
        account pools, request archives, API-key files, and other runtime state.
      '';
    };

    authDir = mkOption {
      type = types.str;
      default = "${stateDir}/auths";
      defaultText = lib.literalExpression ''"''${config.services.dataEraserc.workbuddy2api.stateDir}/auths"'';
      description = "Writable WorkBuddy account directory, exported as WB2A_AUTH_DIR and IDEAUTH_AUTH_DIR.";
    };

    stateFile = mkOption {
      type = types.str;
      default = "${stateDir}/data/state.json";
      defaultText = lib.literalExpression ''"''${config.services.dataEraserc.workbuddy2api.stateDir}/data/state.json"'';
      description = "Main mutable pool state file, exported as WB2A_STATE_FILE.";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "Address on which the API and management panel listen. An empty string means all interfaces.";
    };

    port = mkOption {
      type = types.port;
      default = 7863;
      description = "TCP port serving the OpenAI-compatible API and management panel.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the configured TCP port in the firewall.";
    };

    configMode = mkOption {
      type = types.enum [
        "seed-only"
        "on-change"
        "overwrite"
      ];
      default = "seed-only";
      description = ''
        How the module manages the panel-writable config file. `seed-only`
        creates it only when empty, `on-change` preserves panel edits until the
        declared settings change, and `overwrite` restores declared settings on
        every service start. The listen address, port, auth directory, and state
        file are additionally forced through WB2A_* environment variables, so
        moving the port in the port registry takes effect on the next restart
        without touching the panel-edited file.
      '';
    };

    apiKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/run/secrets/workbuddy2api-api-key";
      description = ''
        File containing the gateway API key. It is loaded through a systemd
        credential and exported as WB2A_API_KEY without entering the Nix store.
        When unset, the service generates `${stateDir}/api-key` on first start
        (mode 0600) so the gateway is authenticated even on a wide bind.
      '';
    };

    enableGeneratedApiKey = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to generate `${stateDir}/api-key` on first start when no other
        API key is configured. The generated key is read only by the service
        account and never enters the Nix store; remove it and restart to rotate.
      '';
    };

    deviceTokenFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/run/secrets/workbuddy2api-device-token";
      description = ''
        File containing the global upstream device token. It is loaded as a
        systemd credential and exposed through WB2A_DEVICE_TOKEN_FILE, allowing
        the upstream five-minute file cache to observe rotations.
      '';
    };

    upstashTokenFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/run/secrets/workbuddy2api-upstash-token";
      description = ''
        File containing the Upstash token. The credential is merged into the
        writable runtime config immediately before startup and never appears in
        a store-generated JSON file.
      '';
    };

    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/run/secrets/workbuddy2api.env";
      description = "Optional systemd EnvironmentFile for runtime-only or secret environment values.";
    };

    extraReadWritePaths = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/srv/workbuddy2api" ];
      description = "Additional existing paths made writable when environment variables point outside stateDir.";
    };

    settings = mkOption {
      type = types.submodule {
        freeformType = jsonFormat.type;
        options = {
          server = sectionOption "HTTP server settings." {
            read_timeout = setting types.str "300s" "Maximum total request read time; 0 disables the limit.";
          };
          panel = sectionOption "Management panel settings." {
            package_detail_limit =
              setting types.int 5
                "Default number of recent credit packages shown per account.";
          };
          logging = sectionOption "Request metadata archive settings." {
            request_archive_enabled = setting types.bool true "Whether request metadata is archived as JSONL.";
            request_retention_days = setting types.int 7 "Archive retention in days.";
            request_archive_max_mb = setting types.int 100 "Maximum total archive size in MiB.";
            request_client_info = setting types.bool true "Whether client IP and User-Agent are recorded.";
          };
          cooldown = sectionOption "Rate-limit cooldown settings." {
            soft_rate = setting types.str "600s" "Base soft rate-limit cooldown.";
            soft_rate_max = setting types.str "2h" "Maximum exponential soft cooldown.";
          };
          schedule = sectionOption "Scheduled account maintenance settings." {
            checkin_hours = setting hoursType [
              9
              21
            ] "Daily WorkBuddy check-in hours.";
            growth_hours = setting hoursType [ 1 ] "Daily growth-task hours.";
            ide_checkin_hours = setting hoursType [
              9
            ] "Daily Qoder, WorkBuddy, and MiniMax pool check-in hours.";
            travel_hours = setting hoursType [
              9
              21
            ] "Daily cat-travel task hours.";
            activity_hours = setting hoursType [ 10 ] "Daily activity-report hours.";
            keepalive_hours = setting hoursType [ 22 ] "Daily token keepalive hours.";
            blackcat_hours = setting hoursType [ 23 ] "Daily night-task hours.";
            checkin_enabled = setting types.bool true "Whether WorkBuddy check-in is scheduled.";
            growth_enabled = setting types.bool true "Whether growth tasks are scheduled.";
            ide_checkin_enabled = setting types.bool true "Whether IDE account-pool check-in is scheduled.";
            travel_enabled = setting types.bool true "Whether travel tasks are scheduled.";
            activity_enabled = setting types.bool true "Whether activity reports are scheduled.";
            keepalive_enabled = setting types.bool true "Whether token keepalive is scheduled.";
            blackcat_enabled = setting types.bool true "Whether night tasks are scheduled.";
            balance_refresh_enabled = setting types.bool true "Whether balances refresh in the background.";
            balance_refresh_minutes = setting types.int 5 "Balance refresh interval in minutes.";
            include_disabled_in_tasks =
              setting types.bool false
                "Whether maintenance tasks include disabled accounts.";
          };
          global = sectionOption "International WorkBuddy routing settings." {
            enabled = setting types.bool true "Whether global-realm accounts use international routing.";
            chat_base = setting types.str "" "Optional international chat base URL override.";
            billing_base = setting types.str "" "Optional international billing base URL override.";
          };
          upstream = sectionOption "Upstream HTTP and client identity settings." {
            timeout_seconds = setting types.int 120 "Timeout for short upstream RPCs.";
            header_timeout_seconds =
              setting types.int 0
                "SSE response-header timeout; non-positive values fall back to timeout_seconds.";
            idle_timeout_seconds =
              setting types.int 0
                "SSE stream idle timeout; non-positive values fall back to 300 seconds.";
            user_agent = setting types.str "" "Explicit outbound User-Agent override.";
            client_version = setting types.str "" "WorkBuddy client version used in outbound identity headers.";
            cli_version = setting types.str "" "CLI version used in the outbound User-Agent.";
            client_name = setting types.str "" "Client name used in usage-attribution headers.";
            device_token_file =
              setting types.str ""
                "Path read by upstream as a periodically refreshed device-token source.";
            passthrough_ip = setting types.bool false "Whether client IP addresses are forwarded upstream.";
          };
          features = sectionOption "Feature gates." {
            sanitize_blacklist_fingerprints =
              setting types.bool true
                "Whether blacklisted request fingerprints are sanitized.";
          };
          prompt = sectionOption "System-prompt handling settings." {
            mode = setting (types.enum [
              "passthrough"
              "custom"
              "append"
            ]) "passthrough" "Whether to pass through, replace, or append to client system prompts.";
            file = setting types.str "" "Custom prompt file used by custom and append modes.";
          };
          upstash = sectionOption "Optional Upstash/Redis mirror settings." {
            url = setting types.str "" "Upstash Redis URL or REST host; an empty value selects in-memory mode.";
          };
          pool = sectionOption "Account selection, concurrency, and circuit-breaker settings." {
            max_in_flight = setting types.int 3 "Maximum concurrent requests per account; 0 means unlimited.";
            max_in_flight_global = setting types.int 2 "Maximum concurrent requests per global-realm account.";
            breaker_threshold = setting types.int 3 "Consecutive failures before circuit breaking.";
            breaker_cooldown = setting types.str "30m" "Initial circuit-breaker cooldown.";
            breaker_cooldown_max = setting types.str "6h" "Maximum exponential circuit-breaker cooldown.";
            degrade_threshold =
              setting types.int 5
                "Consecutive transport failures before temporary degradation.";
            degrade_cooldown = setting types.str "10m" "Temporary degradation duration.";
            degrade_cooldown_max = setting types.str "2h" "Maximum degradation duration.";
            idle_weight_per_hour = setting types.float 0.5 "Selection weight added per idle hour.";
            idle_weight_max = setting types.float 5.0 "Maximum idle-account selection bonus.";
            prefer_expiring =
              setting types.bool true
                "Whether accounts with soon-expiring credits receive extra weight.";
            expiring_soon =
              setting types.str "168h"
                "Window in which credits count as soon expiring; empty or 0 disables it.";
            cost_explore_interval =
              setting types.str "30m"
                "Interval between lower-priority cost-tier exploration attempts; 0 disables it.";
            credit_floor =
              setting types.int 0
                "Minimum balance retained before measured paid models stop using an account.";
          };
          session_sticky = sectionOption "Session-to-account stickiness settings." {
            enabled = setting types.bool true "Whether conversations remain bound to an account.";
            ttl = setting types.str "30m" "Session binding lifetime.";
            gc_interval = setting types.str "5m" "Session-binding garbage-collection interval.";
          };
          trae = sectionOption "Trae check-in and chat-channel settings." {
            enabled = setting types.bool true "Whether the Trae check-in panel and scheduler are enabled.";
            data_dir =
              setting types.str ""
                "Trae Work Assistant data directory; empty maps to stateDir/trae in this module.";
            auto_hours = setting hoursType [
              9
              21
            ] "Daily Trae auto-check-in hours; an explicit empty list disables automatic check-in.";
            chat = sectionOption "Trae model-channel settings." {
              enabled = setting types.bool true "Whether trae:-prefixed models are exposed.";
              max_per_account = setting types.int 2 "Maximum concurrent Trae requests per account.";
              base_url = setting types.str "" "Optional Trae Remote base URL override.";
              first_event_timeout = setting types.str "120s" "Maximum wait for the first Trae event.";
              idle_timeout = setting types.str "180s" "Maximum delay between Trae events.";
              catalog_ttl = setting types.str "30m" "Trae model-catalog cache lifetime.";
            };
          };
        };
      };
      default = { };
      description = ''
        Typed JSON settings written to the panel-mutable configuration. The
        module owns listen, api_key, auth_dir, state_file, upstream.device_token,
        and upstash.token through dedicated options. Unknown future JSON keys
        are accepted, but putting secrets in free-form values copies them into
        the Nix store.
      '';
    };

    environment = mkOption {
      type = types.submodule {
        freeformType = types.attrsOf (
          types.oneOf [
            types.str
            types.int
            types.bool
          ]
        );
        options = {
          TZ = mkOption {
            type = types.nullOr types.str;
            default = "Asia/Shanghai";
            description = "Process time zone used by schedules and logs.";
          };
          WB2A_API_KEY = envString "Direct WB2A_API_KEY value; apiKeyFile is preferred because this value enters the Nix store.";
          WB2A_SOFT_RATE = envString "WB2A_SOFT_RATE override for settings.cooldown.soft_rate.";
          WB2A_SOFT_RATE_MAX = envString "WB2A_SOFT_RATE_MAX override for settings.cooldown.soft_rate_max.";
          WB2A_TIMEOUT_SECONDS = envInt "WB2A_TIMEOUT_SECONDS override for settings.upstream.timeout_seconds.";
          WB2A_HEADER_TIMEOUT_SECONDS = envInt "WB2A_HEADER_TIMEOUT_SECONDS override for the SSE header timeout.";
          WB2A_IDLE_TIMEOUT_SECONDS = envInt "WB2A_IDLE_TIMEOUT_SECONDS override for the SSE idle timeout.";
          WB2A_USER_AGENT = envString "WB2A_USER_AGENT outbound identity override.";
          WB2A_CLIENT_VERSION = envString "WB2A_CLIENT_VERSION outbound client-version override.";
          WB2A_CLI_VERSION = envString "WB2A_CLI_VERSION outbound CLI-version override.";
          WB2A_CLIENT_NAME = envString "WB2A_CLIENT_NAME usage-attribution override.";
          WB2A_DEVICE_TOKEN = envString "Direct WB2A_DEVICE_TOKEN value; deviceTokenFile is preferred because this value enters the Nix store.";
          WB2A_DEVICE_TOKEN_FILE = envString "WB2A_DEVICE_TOKEN_FILE periodically reread by the upstream client.";
          WB2A_PASSTHROUGH_IP = envBool "WB2A_PASSTHROUGH_IP override.";
          WB2A_SANITIZE_FINGERPRINTS = envBool "WB2A_SANITIZE_FINGERPRINTS override.";
          WB2A_PROMPT_MODE = envString "WB2A_PROMPT_MODE override.";
          WB2A_PROMPT_FILE = envString "WB2A_PROMPT_FILE override.";
          WB2A_EXPIRING_SOON = envString "WB2A_EXPIRING_SOON override.";
          WB2A_PREFER_EXPIRING = envBool "WB2A_PREFER_EXPIRING override.";
          WB2A_DEBUG_CHAT = envString "Any non-empty WB2A_DEBUG_CHAT value enables verbose chat debugging.";
          IDEAUTH_AUTH_DIR = envString "WorkBuddy auth directory used by IDE account-pool synchronization.";
          IDEAUTH_POOL_DIR = envString "Directory containing Qoder and WorkBuddy IDE account pools.";
          QODER_DATA_DIR = envString "Qoder desktop data directory override.";
          QODER_PROBE_FILE = envString "Qoder capability-probe state file override.";
          QODER_EGRESS_FILE = envString "Qoder per-account egress policy file override.";
          QODER_UMID_EXE = envString "Qoder UMID helper executable override.";
          QODER_OPENAPI_BASE = envString "Qoder OpenAPI base URL override.";
          TRAE_DATA_DIR = envString "Trae desktop data directory override.";
          TRAE_RELAY_DUMP = envString "Any non-empty TRAE_RELAY_DUMP value enables relay event dumps.";
          MINIMAX_TZ = envString "MiniMax check-in settlement time zone.";
          MINIMAX_OAUTH_URL = envString "MiniMax OAuth token endpoint override.";
          MINIMAX_CLIENT_ID = envString "MiniMax OAuth client ID override.";
          MINIMAX_OAUTH_SCOPE = envString "MiniMax OAuth scope override.";
          MINIMAX_OAUTH_AUDIENCE = envString "MiniMax OAuth audience override.";
          MINIMAX_POOL_FILE = envString "MiniMax account-pool file.";
          MINIMAX_ACCOUNT_ORIGIN_GLOBAL = envString "MiniMax global account origin override.";
          MINIMAX_ACCOUNT_ORIGIN_CN = envString "MiniMax China account origin override.";
          MINIMAX_AUTH_FILE = envString "MiniMax desktop auth.json override.";
          CODEARTS_SLOT_ROOT = envString "CodeArts per-account browser-profile root.";
          CODEARTS_POOL_FILE = envString "CodeArts account-pool file.";
          CODEARTS_PROXY = envString "Global CodeArts HTTP(S) proxy; may contain credentials, so environmentFile is safer.";
          DOUBAO_USER_DATA_DIR = envString "Doubao desktop browser data directory override.";
          DOUBAO_POOL_FILE = envString "Doubao account-pool file.";
          XDG_CONFIG_HOME = envString "XDG configuration root used by Linux Qoder discovery.";
          HTTPS_PROXY = envString "HTTPS proxy used by Gemini and Go HTTP clients.";
          "https_proxy" = envString "Lowercase HTTPS proxy variant.";
          HTTP_PROXY = envString "HTTP proxy used by Gemini and Go HTTP clients.";
          "http_proxy" = envString "Lowercase HTTP proxy variant.";
          NO_PROXY = envString "Hosts excluded from standard Go proxy handling.";
          "no_proxy" = envString "Lowercase no-proxy variant.";
        };
      };
      default = { };
      description = ''
        Upstream runtime environment variables. Declared entries cover every
        production variable read by the Linux server; free-form entries support
        future variables and dynamic CODEARTS_PROXY_<slot> names. Values are
        stored in the systemd unit, so use credential options or environmentFile
        for secrets.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.dataEraserc.workbuddy2api.package must not be null; apply the repository overlay or set an explicit package.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.stateDir;
        message = "services.dataEraserc.workbuddy2api.stateDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.authDir;
        message = "services.dataEraserc.workbuddy2api.authDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.stateFile;
        message = "services.dataEraserc.workbuddy2api.stateFile must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" renderedSettings.trae.data_dir;
        message = "services.dataEraserc.workbuddy2api.settings.trae.data_dir must be empty or an absolute path.";
      }
      {
        assertion = !(cfg.apiKeyFile != null && cfg.environment.WB2A_API_KEY != null);
        message = "Set only apiKeyFile or environment.WB2A_API_KEY; the credential file is recommended.";
      }
      {
        assertion =
          !(
            cfg.deviceTokenFile != null
            && (cfg.environment.WB2A_DEVICE_TOKEN != null || cfg.environment.WB2A_DEVICE_TOKEN_FILE != null)
          );
        message = "Set only deviceTokenFile or a WB2A device-token environment value; the credential file is recommended.";
      }
      {
        assertion = !(builtins.hasAttr "WB2A_LISTEN" cfg.environment);
        message = "Use services.dataEraserc.workbuddy2api.listenAddress and port instead of environment.WB2A_LISTEN.";
      }
      {
        assertion = !(builtins.hasAttr "WB2A_AUTH_DIR" cfg.environment);
        message = "Use services.dataEraserc.workbuddy2api.authDir instead of environment.WB2A_AUTH_DIR.";
      }
      {
        assertion = !(builtins.hasAttr "WB2A_STATE_FILE" cfg.environment);
        message = "Use services.dataEraserc.workbuddy2api.stateFile instead of environment.WB2A_STATE_FILE.";
      }
      {
        assertion = managedSettingKeys == [ ];
        message = "settings contains ${lib.concatStringsSep ", " managedSettingKeys}, which are owned by dedicated options; use listenAddress/port, apiKeyFile, authDir, and stateFile instead.";
      }
      {
        assertion = secretSettingKeys == [ ];
        message = "settings contains ${lib.concatStringsSep ", " secretSettingKeys}, which would copy a secret into the Nix store; use deviceTokenFile or upstashTokenFile instead.";
      }
      {
        assertion = cfg.user == "workbuddy2api" || builtins.hasAttr cfg.user config.users.users;
        message = "A custom services.dataEraserc.workbuddy2api.user must already exist.";
      }
      {
        assertion = cfg.group == "workbuddy2api" || builtins.hasAttr cfg.group config.users.groups;
        message = "A custom services.dataEraserc.workbuddy2api.group must already exist.";
      }
    ];

    warnings =
      lib.optional
        (
          !lib.elem cfg.listenAddress [
            "127.0.0.1"
            "::1"
            "localhost"
          ]
          && cfg.apiKeyFile == null
          && cfg.environment.WB2A_API_KEY == null
          && !cfg.enableGeneratedApiKey
          && cfg.environmentFile == null
        )
        "WorkBuddy2API is listening beyond loopback without any API key; configure apiKeyFile, enable the generated key, or protect it behind an authenticated TLS reverse proxy."
      ++ lib.optional (
        cfg.environment.WB2A_API_KEY != null
      ) "environment.WB2A_API_KEY is copied into the Nix store; use apiKeyFile instead."
      ++ lib.optional (
        cfg.environment.WB2A_DEVICE_TOKEN != null
      ) "environment.WB2A_DEVICE_TOKEN is copied into the Nix store; use deviceTokenFile instead.";

    users.users = lib.mkIf (cfg.user == "workbuddy2api") {
      workbuddy2api = {
        isSystemUser = true;
        inherit (cfg) group;
        home = stateDir;
        description = "WorkBuddy2API gateway service";
      };
    };

    users.groups = lib.mkIf (cfg.group == "workbuddy2api") {
      workbuddy2api = { };
    };

    systemd.services.workbuddy2api = {
      description = "WorkBuddy2API multi-provider gateway and panel";
      documentation = [ "https://github.com/xu20060420fan-cell/workbuddy2api-trae-qoder-minimax-panel" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = serviceEnvironment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = stateDir;
        ExecStartPre = prepareConfig;
        ExecStart = startScript;
        Restart = "on-failure";
        RestartSec = 5;
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        LoadCredential =
          lib.optional (cfg.apiKeyFile != null) "api-key:${cfg.apiKeyFile}"
          ++ lib.optional (cfg.deviceTokenFile != null) "device-token:${cfg.deviceTokenFile}"
          ++ lib.optional (cfg.upstashTokenFile != null) "upstash-token:${cfg.upstashTokenFile}";
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RemoveIPC = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
        ReadWritePaths = lib.unique (
          [
            stateDir
            cfg.authDir
            (builtins.dirOf cfg.stateFile)
          ]
          ++ cfg.extraReadWritePaths
        );
      }
      // lib.optionalAttrs useStateDirectory {
        StateDirectory = [ (builtins.baseNameOf stateDir) ];
        StateDirectoryMode = "0700";
      };
    };

    system.activationScripts.workbuddy2api = lib.stringAfter [ "users" ] ''
      ${pkgs.coreutils}/bin/install -d -m 0700 \
        ${lib.escapeShellArg stateDir} \
        ${lib.escapeShellArg cfg.authDir} \
        ${lib.escapeShellArg (builtins.dirOf cfg.stateFile)}
      chown ${lib.escapeShellArg "${cfg.user}:${cfg.group}"} \
        ${lib.escapeShellArg stateDir} \
        ${lib.escapeShellArg cfg.authDir} \
        ${lib.escapeShellArg (builtins.dirOf cfg.stateFile)}
    '';

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
