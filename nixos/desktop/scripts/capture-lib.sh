# Shared by ocr and pin (prepended as a preamble by default.nix).
#
# freeze_region <out.png>
#   Freezes the screen (wayfreeze) so moving content holds still, lets the user
#   drag a region (slurp) and saves it as a PNG (grim). Returns 1 when the
#   selection is cancelled or the capture fails; the screen is always unfrozen.
freeze_region() {
  local out="$1" ready geometry freezer
  ready="${XDG_RUNTIME_DIR:-/tmp}/freeze-ready.$$"
  rm -f "$ready"
  wayfreeze --after-freeze-cmd "touch $ready" >/dev/null 2>&1 &
  freezer=$!
  # Wait (bounded, 2 s) for the frozen frame to be on screen before slurp.
  for _ in $(seq 40); do
    [ -e "$ready" ] && break
    sleep 0.05
  done
  geometry=$(slurp 2>/dev/null) || geometry=""
  if [ -n "$geometry" ]; then
    grim -g "$geometry" "$out" || geometry=""
  fi
  kill "$freezer" 2>/dev/null || true
  wait "$freezer" 2>/dev/null || true
  rm -f "$ready"
  [ -n "$geometry" ]
}
