{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

# HumanLayer / Riptide desktop app (Tauri).
#
# Distributed by upstream only as a notarized, Developer ID-signed macOS DMG
# (arm64). We mirror the Homebrew cask `humanlayer` exactly: same URL, same
# checksum. `source.json` is regenerated from that cask by scripts/update.sh,
# so this derivation never needs hand-editing on a version bump.
let
  source = lib.importJSON ./source.json;
in
stdenvNoCC.mkDerivation {
  pname = "humanlayer";
  version = source.version;

  src = fetchurl {
    inherit (source) url;
    hash = source.sha256;
  };

  nativeBuildInputs = [ undmg ];

  # undmg extracts `HumanLayer.app` into the current directory; stay there.
  sourceRoot = ".";
  unpackPhase = ''
    runHook preUnpack
    undmg "$src"
    runHook postUnpack
  '';

  # The .app is already signed with a Developer ID and notarized. Nix's fixup
  # phase would strip / re-sign the Mach-O binaries and invalidate that
  # signature, so Gatekeeper would refuse to launch it. Leave the bytes alone.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R "HumanLayer.app" "$out/Applications/HumanLayer.app"

    # Expose the bundled command-line binaries (currently just the `riptided`
    # daemon) on PATH. Loop so future bundled binaries are picked up too.
    mkdir -p "$out/bin"
    binDir="$out/Applications/HumanLayer.app/Contents/Resources/bin"
    if [ -d "$binDir" ]; then
      for b in "$binDir"/*; do
        [ -f "$b" ] || continue
        ln -s "$b" "$out/bin/$(basename "$b")"
      done
    fi

    runHook postInstall
  '';

  meta = {
    description = "HumanLayer (Riptide) — AI coding agent powered by Claude, desktop app";
    longDescription = ''
      Unofficial Nix package of the HumanLayer / Riptide desktop application,
      repackaged from the official Homebrew cask (a notarized macOS DMG). The
      app bundle also ships the `riptided` background daemon, which is linked
      onto PATH. Apple Silicon (aarch64-darwin) only, matching upstream.
    '';
    homepage = "https://humanlayer.dev/";
    downloadPage = "https://github.com/humanlayer/humanlayer/releases";
    changelog = "https://github.com/humanlayer/humanlayer/releases";
    # The app's source (github.com/humanlayer/humanlayer — the Tauri GUI, the
    # `hld`/riptided daemon, the `hlyr` CLI) is Apache-2.0, and this is the
    # standard (non-"Pro") build. The hosted service and "Pro" builds have
    # separate proprietary terms and are not what this package installs.
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
    mainProgram = "riptided";
    maintainers = [ ];
  };
}
