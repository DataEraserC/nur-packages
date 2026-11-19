# workbuddy2api-panel packaging notes

- Follow the upstream `go` directive with `buildGo126Module`; an older generic Go builder fails before dependency hashes can be updated.
- Build the four binaries shipped by the Docker image. Rename only `cmd/server` to the upstream release name `wb2api`; keep `signin`, `login`, and `credit` at their command names.
- Keep `nodejs_26` in `nativeCheckInputs` and run `go test ./...`: the panel JavaScript is embedded into the Go binary, and its syntax/runtime smoke tests only execute when `node` is available.
- Keep `CGO_ENABLED=0`, matching upstream release and container builds.
- `internal/ideauth` has two wall-clock-dependent ledger tests (`TestQoderClaimHistoryStickyClaimed`, `TestQoderClaimHistoryAuditsAllPhases`) that derive "today" as `time.Now() - 1..3h`; between 00:00 and 03:00 CST the records collapse onto yesterday's date and the assertions fail. Skip exactly those two with `go test -skip=...` and keep the rest of the suite running; drop the skip once upstream anchors the fixtures to a fixed time of day.
