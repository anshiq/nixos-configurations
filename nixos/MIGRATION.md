# Migration notes: WSL to native NixOS

## Preserved

- Fish aliases and functions
- Helix and its language tooling
- Yazi configuration and plugins
- Development toolchains
- Zellij layout and every existing Zellij keybinding

## Changed

- Zellij's colors now use the Omarchy Tokyo Night palette.
- Ghostty replaces the previous Windows-side/Alacritty assumption.
- Hyprland is the native compositor, backed by UWSM and SDDM.
- Google Chrome is installed and registered for HTTP/HTTPS; Firefox is installed as a secondary browser.
- JetBrainsMono Nerd Font supplies terminal and Waybar glyphs; Noto fonts and Noto Color Emoji provide broad fallback coverage.
- Native NetworkManager, Bluetooth, PipeWire, portals, Polkit, and keyring services replace WSL/Windows integration.

## Deliberately not copied from Omarchy

Omarchy's current Hyprland configuration is Lua-generated and relies on its own runtime, shell, commands, package names, and Arch Linux services. Importing those files directly would create hidden runtime dependencies and would not be stable on NixOS.

The Nix modules instead translate the durable parts requested here:

- Tokyo Night palette and wallpaper
- Omarchy-like gaps, borders, dwindle behavior, animations, input defaults, gestures, and core window bindings
- Ghostty font, padding, cursor, scroll, and Wayland performance settings
- Browser, media, screenshot, lock, clipboard, and workspace controls

It excludes the Omarchy Quickshell desktop, web apps, theme switcher, custom menus, proprietary integrations, tmux launchers, and Arch-specific package/service scripts.

## Keybinding isolation

- Hyprland reserves `Super` combinations for operating-system/window actions.
- Zellij retains its existing `Ctrl` combinations.
- Ghostty uses `Shift+Insert`, `Ctrl+Insert`, and `Shift+Enter`; it does not consume Zellij's `Ctrl` letter bindings.
- Omarchy's tmux-specific launch/keybinding actions were not copied.

## Native-only requirements

`configuration.nix` imports `hardware-configuration.nix`. This file must be generated on the target native machine, because its filesystems, boot modules, and hardware details cannot be derived from WSL.

GPU-specific configuration is also intentionally deferred until the native machine can report its hardware (`lspci -nnk`). Generic Intel/AMD Mesa support comes from NixOS defaults; NVIDIA commonly needs an explicit driver selection.

## WSL and Windows properties

The WSL flake input/module and `wsl.*` options remain commented as migration history. The Windows-side `docker.exe` alias, tmuxifier path, and global `LD_LIBRARY_PATH` workaround are no longer active. A global `LD_LIBRARY_PATH` is especially undesirable on native NixOS because it can override per-package dependency resolution.
