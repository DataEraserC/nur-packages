{
  qoder-cn,
  python3,
}:
qoder-cn.overrideAttrs (old: {
  pname = "qoder-cn-wayland";

  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ python3 ];

  # The asar is a single binary blob, so it cannot go through patchPhase.
  # repack-asar.py fails loudly when the upstream anchor moves, so a version
  # bump cannot silently ship an unpatched app.
  postInstall = (old.postInstall or "") + ''
    python3 ${./repack-asar.py} $out/opt/Qoder-CN/resources/app.asar
  '';

  meta = (old.meta or { }) // {
    description = "Qoder CN App with the Wayland/waypipe ready-to-show fallback";
  };
})
