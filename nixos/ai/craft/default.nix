# ArtCraft apps (the list is apps.nix): desktop apps, CLIs, `<name>-live`
# launchers and `<name>-mcp-live` bridges.
# Versions live in apps.nix; their MCP entries are in ../mcp.nix.
# examples/ holds reference scripts that drive the live apps (not installed).
{ pkgs, ... }:

let
  craft = pkgs.callPackage ./packages.nix { };
in
{
  home.packages = craft.all;
}
