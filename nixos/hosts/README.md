# Hosts: one folder per machine

Everything shared by all machines lives in `configuration.nix`, `home.nix` and
`desktop/`. What differs between machines lives here and in `modules/hardware/`.

```
hosts/<name>/default.nix                  which hardware modules this machine uses, hostname, overrides
hosts/<name>/hardware-configuration.nix   output of nixos-generate-config (disks, kernel modules, CPU arch)
hosts/examples/<template>/                templates for new machines (not built)
modules/hardware/*.nix                    reusable hardware pieces, see below
```

`flake.nix` builds one system per `hosts/<name>/` folder automatically - there is
nothing to register. The CPU architecture (x86_64 / aarch64) comes from
`nixpkgs.hostPlatform` in that host's `hardware-configuration.nix`.

Current machine: `hosts/laptop-amd` (also reachable as `#nixos`).

## Add a machine

On the new machine, from a checkout of this repo at `/etc/nixos`:

```bash
hosts/new-host.sh <name> [template]     # template: desktop-intel (default) | laptop-nvidia
$EDITOR hosts/<name>/default.nix        # pick the modules below
nix build .#nixosConfigurations.<name>.config.system.build.toplevel
sudo nixos-rebuild boot --flake /etc/nixos#<name>   # first time: boot, then reboot
```

New folders must be known to git (`git add -N hosts/<name>`; the script does it)
or the flake cannot see them.

## Hardware modules (`hardwareModules.<name>` in a host's `imports`)

| Module | Use it when |
|--------|-------------|
| `boot-uefi` | UEFI machine (almost everything modern) |
| `boot-bios` | Legacy BIOS; also set `boot.loader.grub.device = "/dev/sdX";` |
| `cpu-amd` / `cpu-intel` | KVM + microcode (+ thermald on Intel) |
| `gpu-amd` | AMD graphics (amdgpu) |
| `gpu-intel` | Intel integrated graphics, with VA-API video acceleration |
| `gpu-nvidia` | NVIDIA proprietary driver; hybrid laptops also set `hardware.nvidia.prime.*` (see `examples/laptop-nvidia`) |
| `laptop` | Has a battery: UPower for the bar widget, low-battery alerts, power page |
| `vm-guest` | Runs in a VM; set `desktop.vmGuest = "qemu" \| "virtualbox" \| "vmware"` |

A desktop PC just leaves `laptop` out. Add a new piece by dropping a file in
`modules/hardware/`; it is picked up as `hardwareModules.<file name>`.

## What adapts at runtime (no per-host setting needed)

- **Monitors** (`hypr/hyprland.lua`): workspaces 1-5 go to the built-in panel
  (`eDP-*`, `LVDS-*`, `DSI-*`) or, on a desktop, the first monitor; 6-10 to the
  next monitor. Any port names work.
- **Idle dim/suspend** (`desktop/scripts/on-battery.sh`): only on battery. A
  machine with no battery (desktop, VM) never dims or suspends by itself.
- **Battery widget / alerts**: hidden or silent when there is no battery.

## Testing a host without installing it

```bash
# evaluate (fast) / build (slow) any host, including the templates:
nix eval --impure --expr 'let f = builtins.getFlake "/etc/nixos"; in
  (f.lib.mkHost /etc/nixos/hosts/examples/laptop-nvidia).config.system.build.toplevel.drvPath'
```
Only x86_64 hosts can be booted/tested natively here; NVIDIA (unfree driver),
aarch64 and BIOS hosts are only evaluated, not run, until they exist as real
hardware.
