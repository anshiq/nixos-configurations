# Third-party Quickshell bar-widget plugins, declared here and fetched
# reproducibly by Nix - the declarative equivalent of Omarchy's
# `omarchy-plugin-clone` (a runtime `git clone` into
# ~/.config/omarchy/plugins/<id>). Every entry is pinned to an exact
# revision and content hash, so `nixos-rebuild switch` is what "installs" a
# plugin: no separate imperative step, and the same plugin code is
# reproduced bit-for-bit on any machine building this flake.
#
# Each entry's `src` must be a repo whose root has a manifest.json following
# the same contract as the first-party plugins under ../quickshell/plugins/
# (see e.g. ../quickshell/plugins/user.clock/manifest.json): id, name, kind
# ("bar-widget"), entryPoint, section, tooltip. desktop/home.nix's
# quickshellPlugins activation step symlinks `src` straight into
# ~/.config/quickshell/plugins/<id> (the id used as the attribute name
# below) and regenerates plugin-registry.json - see there. Enabling a
# fetched plugin on the bar still goes through
# quickshell/scripts/plugin.sh enable <id> [left|center|right], exactly
# like a first-party one.
#
# Adding a plugin = add one entry here (github or any other
# fetchTarball/fetchgit-compatible provider works, not just GitHub) -
# nothing else in this repo needs to change.
{ pkgs }:
{
  # A real Omarchy-catalog plugin (https://omarchyplugins.com), fetched
  # reproducibly instead of Omarchy's runtime `omarchy plugin add
  # <url> --enable` git-clone. Pinned to a commit (never a branch) - refresh
  # with:
  #   nix run nixpkgs#nix-prefetch-github -- ianswope omarchy-plex
  #
  # Known limitation, not fixed by this fetch: this plugin's QML imports
  # `qs.Commons`/`qs.Ui` (Omarchy's own Style/Color/BarIconButton/etc.
  # design-system modules), which don't exist in this shell - it will fetch
  # and place correctly but its widget will fail to load until those
  # modules are ported/shimmed here. Kept declared (rather than removed) as
  # the reference case for that gap.
  "ianswope.plex" = {
    name = "Plex";
    src = pkgs.fetchFromGitHub {
      owner = "ianswope";
      repo = "omarchy-plex";
      rev = "da8921afadfd979b22727ad16111b145b10ec611";
      hash = "sha256-wpOaFnd9MH6bcMSXB5Wjp8h6mg4ccnonmPMR9lW9iGk=";
    };
  };

  # Example (commented out - replace with a real plugin repo, or delete):
  #
  # "example.weather" = {
  #   name = "Weather";
  #   src = pkgs.fetchFromGitHub {
  #     owner = "someone";
  #     repo = "quickshell-weather-widget";
  #     rev = "v1.2.0"; # a tag or commit - never a branch, for reproducibility
  #     hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  #     # Get the real hash: nix run nixpkgs#nix-prefetch-github -- someone quickshell-weather-widget --rev v1.2.0
  #   };
  # };
  #
  # A non-GitHub provider works the same way, e.g. a plain git remote:
  #
  # "example.other" = {
  #   name = "Other Widget";
  #   src = pkgs.fetchgit {
  #     url = "https://gitlab.com/someone/quickshell-other-widget.git";
  #     rev = "v0.3.0";
  #     hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  #   };
  # };
}
