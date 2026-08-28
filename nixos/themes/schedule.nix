# Wall-clock auto-switch schedule, kept separate from the palettes in
# ./default.nix so the schedule can change without touching colors and vice
# versa. Each entry's theme runs from its `time` until the next entry's
# `time`, wrapping around midnight (the last entry runs until the first
# entry's time the next day). Consumed by desktop/home.nix to generate one
# systemd.user timer+service pair per entry, and rendered to
# waybar/scripts/schedule.list for theme-switch.sh's no-arg (clock-based)
# lookup.
[
  {
    time = "05:00";
    theme = "mono";
  }
  {
    time = "07:00";
    theme = "forest-green";
  }
  {
    time = "09:00";
    theme = "ocean-blue";
  }
  {
    time = "17:00";
    theme = "sunset-night";
  }
]
