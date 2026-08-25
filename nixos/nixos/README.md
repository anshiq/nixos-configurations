# Native NixOS + Hyprland configuration

This flake migrates the previous WSL development setup to native NixOS without installing a full GNOME/KDE desktop. It keeps the existing Fish, Helix, Yazi, development tools, and Zellij workflow, and adds a focused Wayland desktop inspired by Omarchy.

## Desktop stack

- Hyprland launched through UWSM, with SDDM login
- Ghostty with JetBrainsMono Nerd Font and Tokyo Night colors
- Waybar, Wofi, Mako, Hyprlock, and Hypridle
- Chromium as the default browser
- NetworkManager, Bluetooth, PipeWire, portals, Polkit, and keyring support
- Tokyo Night wallpaper and matching UI colors
- Screenshot, clipboard history, media, volume, brightness, lock, workspace, and window bindings

This does **not** import Omarchy's complete shell, package set, menus, daemons, web apps, or Arch-specific scripts.

## Layout

```text
local-nixos-config/
├── flake.nix
├── configuration.nix
├── hardware-configuration.nix.example
├── home.nix
├── desktop/
│   ├── system.nix             # Native display, audio, portals, fonts, browser
│   └── home.nix               # Hyprland and all desktop application config
├── helix/
└── yazi/
```

## Required native hardware file

A native system cannot safely reuse WSL hardware assumptions. Generate the target machine's file from the NixOS installer:

```bash
sudo nixos-generate-config --root /mnt
```

Copy this repository to `/mnt/etc/nixos`, but retain the generated `/mnt/etc/nixos/hardware-configuration.nix`. Do not rename `hardware-configuration.nix.example`; it is documentation only.

The real generated file contains filesystems, initrd modules, CPU defaults, and hardware-specific storage settings. This repository intentionally does not invent those values.

## Install

From the installer after mounting the target filesystems at `/mnt`:

```bash
sudo nixos-generate-config --root /mnt
sudo cp -r /path/to/local-nixos-config/. /mnt/etc/nixos/
# Restore/retain the generated hardware-configuration.nix if the copy source differs.
sudo nixos-install --flake /mnt/etc/nixos#nixos
```

After reboot, choose **Hyprland (UWSM)** in SDDM if it is not selected automatically.

For later changes:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

## Important customizations

### Username

The config assumes the user is `nixos` in:

- `configuration.nix`: `users.users.nixos`
- `flake.nix`: `home-manager.users.nixos`
- `home.nix`: `home.username` and `home.homeDirectory`

Change all four together if the native account has another name.

### Monitor configuration

The portable default in `desktop/home.nix` is:

```nix
monitor = ",preferred,auto,auto";
```

After booting, run `hyprctl monitors all` and replace/add entries for exact resolution, refresh rate, position, and scale if needed.

### GPU configuration

The generic Hyprland setup works for Intel/AMD Mesa systems. NVIDIA may require driver settings based on the exact card and driver branch. Add those only after checking `lspci -nnk` on the native machine; they are deliberately not guessed here.

## Keybindings

Hyprland uses `Super`, leaving the existing Zellij `Ctrl` bindings unchanged. Ghostty also avoids `Ctrl` letter shortcuts, so keys such as `Ctrl+h/j/k/l`, `Ctrl+n`, `Ctrl+p`, and `Ctrl+t` reach Zellij.

| Binding | Action |
|---|---|
| `Super+Enter` | Ghostty |
| `Super+Shift+Enter` / `Super+Shift+B` | Chromium |
| `Super+Space` | Application launcher |
| `Super+Q` / `Super+W` | Close window |
| `Super+Arrow` | Move focus |
| `Super+Shift+Arrow` | Swap window |
| `Super+1..9` | Switch workspace |
| `Super+Shift+1..9` | Move window to workspace |
| `Super+F` | Fullscreen |
| `Super+T` | Toggle floating |
| `Super+S` | Toggle scratchpad |
| `Super+Ctrl+L` | Lock |
| `Print` | Select screenshot and copy it |
| `Super+V` | Clipboard history |

Zellij's existing bindings and `dev` layout remain in `home.nix`; only its color theme now matches Tokyo Night.

## WSL migration status

The `nixos-wsl` input/module and all `wsl.*` settings are commented out. Windows Docker interop, the tmuxifier path, and the global `LD_LIBRARY_PATH` workaround were removed/disabled for native stability. `nix-ld` remains available for explicitly required unpatched binaries.
