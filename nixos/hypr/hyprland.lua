-- Fixed for Hyprland 0.56.x Lua API.
-- See https://wiki.hypr.land/Configuring/Start/

-------------------
---- PROGRAMS ----
-------------------

local terminal = "ghostty"
local browser  = "google-chrome-stable"
local browser2 = "firefox"
local menu     = "wofi --show drun --allow-images"
local mod      = "SUPER"

------------------
---- MONITOR ----
------------------

hl.monitor({
  output   = "",
  mode     = "preferred",
  position = "auto",
  scale    = "auto",
})

-- NOTE: render { explicit_sync = 0 } (old zed workaround) is GONE in 0.50+:
-- explicit sync is now always enabled by default in Hyprland, so the option
-- was removed upstream and has no Lua equivalent in 0.56.x.
-- If zed still fails to open, that's unrelated to explicit sync.

--------------------------
---- ENVIRONMENT VARS ----
--------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

----------------
---- AUTOSTART ----
----------------

hl.on("hyprland.start", function()
  hl.exec_cmd("waybar")
  -- hl.exec_cmd("mako")
  -- hl.exec_cmd("nm-applet --indicator")
  -- hl.exec_cmd("swaybg -i <wallpaper> -m fill")
  -- hl.exec_cmd("wl-paste --type text --watch cliphist store")
  -- hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-----------------
---- LOOK AND FEEL ----
-----------------

hl.config({
  general = {
    allow_tearing = false,
    border_size   = 2,
    col           = {
      active_border   = { colors = { "rgba(7aa2f7ee)", "rgba(bb9af7ee)" }, angle = 45 },
      inactive_border = "rgba(414868aa)",
    },
    gaps_in          = 5,
    gaps_out         = 10,
    layout           = "dwindle",
    resize_on_border = false,
  },

  decoration = {
    blur   = { enabled = false },
    shadow = { enabled = false },
    rounding = 0,
  },

  cursor = {
    hide_on_key_press = true,
  },

  dwindle = {
    force_split    = 2,
    preserve_split = true,
  },

  input = {
    follow_mouse       = 1,
    kb_layout          = "us",
    kb_options         = "compose:caps,shift:both_capslock_cancel",
    numlock_by_default = true,
    repeat_delay       = 250,
    repeat_rate        = 40,
    sensitivity        = 0,
    touchpad           = {
      clickfinger_behavior = true,
      natural_scroll       = false,
      scroll_factor        = 0.4,
    },
  },

  misc = {
    allow_session_lock_restore = true,
    disable_hyprland_logo      = true,
    disable_splash_rendering   = true,
    focus_on_activate          = true,
  },
})

--------------------
---- ANIMATIONS ----
--------------------

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("quick",        { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global",     enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",     enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",    enabled = true,  speed = 3.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",  enabled = true,  speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true,  speed = 1.49, bezier = "default",      style = "popin 87%" })
hl.animation({ leaf = "fade",       enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",     enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces", enabled = false, speed = 8,    bezier = "default" })

--------------
---- GESTURES ----
--------------

hl.gesture({
  fingers   = 3,
  direction = "horizontal",
  action    = "workspace",
})

---------------------
---- KEYBINDINGS ----
---------------------

-- Launch apps
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + ALT + B", hl.dsp.exec_cmd(browser2))
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd(menu))

-- Windows
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + W", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + G", hl.dsp.group.toggle())

-- Focus windows
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Swap windows
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.swap({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.swap({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.swap({ direction = "down" }))

-- Workspaces
hl.bind(mod .. " + TAB", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))

for i = 1, 9 do
  hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
  hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(mod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- Lock / screenshots / clipboard
hl.bind(mod .. " + CTRL + L", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"))
hl.bind("PRINT", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind(mod .. " + PRINT", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))

-- Media / volume keys
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pamixer --toggle-mute"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pamixer --default-source --toggle-mute"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Repeating binds (volume / brightness)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer --increase 5"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer --decrease 5"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

-- Mouse binds
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

--------------------
---- WINDOW RULES ----
--------------------

hl.window_rule({
  name  = "float-config-windows",
  match = { class = "^(org.pulseaudio.pavucontrol|blueman-manager|nm-connection-editor)$" },
  float = true,
  center = true,
})

hl.window_rule({
  name  = "picture-in-picture",
  match = { title = "^(Picture.?in.?Picture)$" },
  float            = true,
  pin              = true,
  keep_aspect_ratio = true,
})

hl.window_rule({
  name  = "browser-tiled",
  match = { class = "^(google-chrome|Google-chrome|firefox)$" },
  tile  = true,
})
