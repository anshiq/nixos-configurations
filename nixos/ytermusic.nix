# /etc/nixos/ytermusic.nix
#
# YTerMusic (https://github.com/ccgauche/ytermusic), the TUI YouTube Music
# player, installed declaratively. Imported from home.nix.
#
# The upstream package already carries its build inputs (pkg-config, alsa-lib,
# dbus, openssl), so no nix-shell is needed. This module adds:
#   - a yt-dlp newer than the one in the pinned nixpkgs: YouTube answers old
#     yt-dlp builds with HTTP 403, which shows up in ytermusic as every song
#     failing to download (see ~/.cache/ytermusic/log.txt);
#   - node as yt-dlp's JavaScript runtime, which YouTube extraction needs;
#   - a ytermusic wrapper with that yt-dlp on its PATH, because ytermusic
#     shells out to `yt-dlp` and does not look anywhere else.
#
# When `nix flake update` brings in a yt-dlp at least this new, drop the
# overrideAttrs below and use pkgs.yt-dlp directly.
#
# Not managed here: ~/.config/ytermusic/headers.txt holds your YouTube Music
# cookie, and config.toml is rewritten by the app itself.
{ lib, pkgs, ... }:

let
  ytDlp =
    (pkgs.yt-dlp.override {
      # Baked into yt-dlp's store path; the config below turns it on.
      jsRuntime = pkgs.nodejs_22;
    }).overrideAttrs
      (_old: rec {
        version = "2026.08.19";
        src = pkgs.fetchFromGitHub {
          owner = "yt-dlp";
          repo = "yt-dlp";
          tag = version;
          hash = "sha256-BM5ZeGTmHq+1xH6G/zsuCtjLgYgfRA11ya0zIHK5p4g=";
        };
      });

  ytermusic = pkgs.symlinkJoin {
    name = "ytermusic-${pkgs.ytermusic.version}-wrapped";
    paths = [ pkgs.ytermusic ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/ytermusic --prefix PATH : ${lib.makeBinPath [ ytDlp ]}
    '';
    meta.mainProgram = "ytermusic";
  };
in
{
  home.packages = [
    ytermusic
    ytDlp
  ];

  xdg.configFile."yt-dlp/config".text = ''
    --js-runtimes node
  '';
}
