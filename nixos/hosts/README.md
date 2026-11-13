# Hosts: one folder per machine

Everything shared by all machines lives in `configuration.nix`, `home.nix` and
`cli/`. What differs between machines lives here and in `modules/hardware/`.

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
hosts/new-host.sh <name> [template]     # template: generic-intel (default)
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
| `vm-guest` | Runs in a VM; set `desktop.vmGuest = "qemu" \| "virtualbox" \| "vmware"` |

This is the CLI-only branch, so there are no GPU or laptop-battery modules; the
`desktop` branch has them. Add a new piece by dropping a file in
`modules/hardware/`; it is picked up as `hardwareModules.<file name>`.

## Testing a host without installing it

```bash
nix eval --impure --expr 'let f = builtins.getFlake "/etc/nixos"; in
  (f.lib.mkHost /etc/nixos/hosts/examples/generic-intel).config.system.build.toplevel.drvPath'
```
Only x86_64 can be booted natively here; BIOS and aarch64 hosts are evaluated only.
