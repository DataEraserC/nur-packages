{
  sources,
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  inherit (sources.gwmp-mux) pname version src;

  cargoHash = "sha256-0PsG81CuQcpzjJR3lhtCjE4tlD8tpyuzqIaRVS8U8cI=";
  useFetchCargoVendor = true;

  meta = {
    mainProgram = "gwmp-mux";
    maintainers = with lib.maintainers; [ xddxdd ];
    description = "Multiplexer for Semtech's GWMP over UDP";
    homepage = "https://github.com/helium/gwmp-mux";
    license = lib.licenses.asl20;
  };
}
