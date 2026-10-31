# `greeter-sync` (scripts/greeter-sync.sh): publishes the active palette and
# lock-screen wallpaper for the login greeter (desktop/greeter.nix). Run by
# theme-switch, the settings app's Lock screen page, and every activation.
{ lib, pkgs, ... }:

let
  inherit (import ./scripts { inherit pkgs; }) greeter-sync;
in
{
  home.packages = [ greeter-sync ];

  # Seed the greeter on every activation; a failure must never fail activation.
  home.activation.greeterSync = lib.hm.dag.entryAfter [ "writeBoundary" "migrateDesktopState" ] ''
    ${greeter-sync}/bin/greeter-sync || true
  '';
}
