# `greeter-sync`: publishes the current theme palette and lock-screen wallpaper
# for the login greeter (desktop/greeter.nix, desktop/greeter/).
#
# The greeter runs as the unprivileged `greeter` user before anyone logs in, so
# it cannot read ~/.local/state. This copies what it needs into the shared
# directory greeter.nix creates:
#   theme.json  <- ~/.local/state/quickshell/theme.json (what the bar and lock screen use)
#   wallpaper   <- the image chosen on the Settings app's Lock screen page,
#                  else the stock lock wallpaper
#
# Called from waybar/scripts/theme-switch.sh and the Settings app's Lock screen
# page, and once per home-manager activation. Note the copied wallpaper is
# readable by every local user.
{ lib, pkgs, ... }:

let
  greeterSync = pkgs.writeShellApplication {
    name = "greeter-sync";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils # cmp
      jq
    ];
    text = ''
      dest=/var/lib/quickshell-greeter
      state="$HOME/.local/state/quickshell"

      # Nothing to publish into until desktop/greeter.nix has created the
      # directory (it appears at the first boot with the greeter enabled).
      if [ ! -d "$dest" ] || [ ! -w "$dest" ]; then
        exit 0
      fi

      # Copy via a temp file + rename so the greeter never reads a half-written
      # file, and skip the copy when nothing changed.
      publish() {
        if ! cmp -s "$1" "$dest/$2"; then
          cp -L "$1" "$dest/.$2.tmp"
          chmod 0644 "$dest/.$2.tmp"
          mv -f "$dest/.$2.tmp" "$dest/$2"
        fi
      }

      if [ -r "$state/theme.json" ]; then
        publish "$state/theme.json" theme.json
      fi

      wallpaper=""
      if [ -r "$state/lockscreen.json" ]; then
        wallpaper=$(jq -r '.wallpaper // ""' "$state/lockscreen.json" 2>/dev/null || true)
      fi
      if [ -z "$wallpaper" ] || [ ! -r "$wallpaper" ]; then
        wallpaper="$HOME/.config/wallpapers/wallpaper.png"
      fi
      if [ -r "$wallpaper" ]; then
        publish "$wallpaper" wallpaper
      fi
    '';
  };
in
{
  home.packages = [ greeterSync ];

  # Seed the greeter with the current look on every activation (a failure here
  # must never fail the activation).
  home.activation.greeterSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${greeterSync}/bin/greeter-sync || true
  '';
}
