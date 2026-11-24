# One ArtCraft app from its release AppImage: { gui, cli }.
#   gui  the desktop app, run through appimageTools' FHS wrapper (it loads
#        Vulkan, X11/Wayland, fonts and ALSA at runtime), with its menu entry
#        and icon
#   cli  the bundled <name>-cli, extracted and patched to the Nix store; it
#        needs only libc and libgcc_s
{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  autoPatchelfHook,
}:

name:
{
  version,
  hash,
  description,
  ...
}:

let
  src = fetchurl {
    url = "https://github.com/storytold/${name}/releases/download/v${version}/${name}-${version}-linux-x86_64.AppImage";
    inherit hash;
  };

  extracted = appimageTools.extract {
    pname = name;
    inherit version src;
  };

  meta = {
    homepage = "https://github.com/storytold/${name}";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
in
{
  gui = appimageTools.wrapType2 {
    pname = name;
    inherit version src;

    # VA-API for hardware video decode (and encode where the app supports it).
    # The FHS sandbox has no libva by default, so the apps fell back to the CPU.
    # libva finds the system driver (radeonsi/iHD) in /run/opengl-driver/lib/dri.
    extraPkgs = pkgs: [ pkgs.libva ];

    # Menu entry and icon. The .desktop file's Exec=<name> is this wrapper.
    extraInstallCommands = ''
      root=${extracted}
      if [ -d "$root/usr/share/applications" ]; then
        mkdir -p $out/share
        for d in applications icons metainfo mime; do
          [ -d "$root/usr/share/$d" ] && cp -r "$root/usr/share/$d" $out/share/
        done
      else
        install -Dm644 "$root"/*.desktop -t $out/share/applications
      fi
      if [ ! -d "$out/share/icons" ]; then
        install -Dm644 "$root"/*.png -t $out/share/pixmaps
      fi
    '';

    meta = meta // {
      description = "ArtCraft ${description}";
      mainProgram = name;
    };
  };

  cli = stdenv.mkDerivation {
    pname = "${name}-cli";
    inherit version;

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];

    installPhase = ''
      runHook preInstall
      install -Dm755 ${extracted}/usr/bin/${name}-cli $out/bin/${name}-cli
      runHook postInstall
    '';

    meta = meta // {
      description = "ArtCraft ${description}: command line and MCP server";
      mainProgram = "${name}-cli";
    };
  };
}
