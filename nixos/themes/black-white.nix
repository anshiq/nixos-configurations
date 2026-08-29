{
  name = "black-white";
  kind = "night"; # worn 04:00-06:00, the deepest/darkest pre-dawn window

  # Every field below is neutral gray (R=G=B) - zero hue anywhere, by
  # design: this is the "no color at all" window, distinct from `mono`
  # (which keeps a soft gray palette but runs during the day at 09:00-15:00).
  # Differentiation between roles comes from brightness only.
  background = "000000";
  darkBackground = "000000";
  foreground = "ffffff";
  brightForeground = "ffffff";

  muted = "555555";
  selection = "222222";
  selectionForeground = "ffffff";

  red = "808080";
  green = "b3b3b3";
  yellow = "cccccc";
  blue = "999999";
  magenta = "e6e6e6";
  cyan = "a6a6a6";
  accent = "ffffff";
  cursor = "ffffff";

  brightRed = "999999";
  brightGreen = "cccccc";
  brightYellow = "e6e6e6";
  brightBlue = "b3b3b3";
  brightMagenta = "f2f2f2";
  brightCyan = "bfbfbf";

  borderActive1 = "ffffff";
  borderActive2 = "999999";
  borderInactive = "333333";
}
