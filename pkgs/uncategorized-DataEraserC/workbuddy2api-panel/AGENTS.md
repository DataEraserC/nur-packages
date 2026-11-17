# workbuddy2api-panel packaging notes

- Follow the upstream `go` directive with `buildGo126Module`; an older generic Go builder fails before dependency hashes can be updated.
- Build the four binaries shipped by the Docker image. Rename only `cmd/server` to the upstream release name `wb2api`; keep `signin`, `login`, and `credit` at their command names.
- Keep `nodejs_26` in `nativeCheckInputs` and run `go test ./...`: the panel JavaScript is embedded into the Go binary, and its syntax/runtime smoke tests only execute when `node` is available.
- Keep `CGO_ENABLED=0`, matching upstream release and container builds.
