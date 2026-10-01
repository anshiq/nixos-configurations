# Packages the ported Omarchy plugin lifecycle scripts (flake input
# `omarchy-binaries` -> github:anshiq/omarchy-binaries-for-nixos) as
# first-class Nix commands: omarchy-plugin-{add,enable,disable,update,
# remove,clone,list,catalog,validate} + omarchy-git-url-check.
#
# Each script is wrapped with makeWrapper so its runtime deps are on PATH.
# Sibling calls keep working: wrappers exec the originals in the store, so
# each script's BINDIR resolution still finds the rest of bin/.
{
  pkgs,
  lib,
  omarchyBinaries,
  ...
}:

let
  runtimePath = lib.makeBinPath (
    with pkgs;
    [
      bash
      git
      jq
      libnotify
    ]
  );
  omarchyPluginTools = pkgs.runCommand "omarchy-plugin-tools" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p $out/bin
    for f in ${omarchyBinaries}/bin/*; do
      makeWrapper "$f" "$out/bin/$(basename "$f")" --prefix PATH : ${runtimePath}
    done
  '';
in
{
  home.packages = [ omarchyPluginTools ];
}
