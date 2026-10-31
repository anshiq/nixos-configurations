# Wall-clock auto-switch schedule, kept separate from the palettes in
# ./default.nix so the schedule can change without touching colors and vice
# versa. Each entry's theme runs from its `time` until the next entry's
# `time`, wrapping around midnight (the last entry runs until the first
# entry's time the next day). desktop/home.nix generates one systemd user
# timer+service pair per entry and writes the list to
# ~/.config/desktop/schedule.json for theme-switch's no-arg (clock-based)
# lookup. Entries must stay in ascending time order - that lookup depends
# on it.
[
  {
    time = "04:00";
    theme = "black-white";
  }
  {
    time = "06:00";
    theme = "forest-green";
  }
  {
    time = "12:30";
    theme = "mono";
  }
  {
    time = "15:00";
    theme = "sunset-night";
  }
]
