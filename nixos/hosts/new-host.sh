#!/usr/bin/env bash
# Add this machine to the flake.
#   hosts/new-host.sh <name> [template]
# Run it ON the new machine, from a checkout of this repo (/etc/nixos), as your
# normal user (sudo is not needed). Templates are the folders in hosts/examples/
# (default: desktop-intel).
#
# It copies the template to hosts/<name>/, sets the hostname, and replaces the
# placeholder hardware-configuration.nix with this machine's real one. You then
# adjust hosts/<name>/default.nix (CPU, GPU, laptop or not, boot loader) and run:
#   sudo nixos-rebuild boot --flake /etc/nixos#<name>
set -euo pipefail

hosts_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
name=${1:-}
template=${2:-desktop-intel}

if [[ ! $name =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "usage: $0 <name> [template]   (name: lowercase letters, digits, dashes)" >&2
  exit 1
fi
if [[ $name == examples ]]; then
  echo "'examples' is reserved." >&2
  exit 1
fi
if [[ -e $hosts_dir/$name ]]; then
  echo "hosts/$name already exists." >&2
  exit 1
fi
if [[ ! -d $hosts_dir/examples/$template ]]; then
  echo "unknown template '$template'. Available:" >&2
  ls "$hosts_dir/examples" >&2
  exit 1
fi
if ! command -v nixos-generate-config >/dev/null; then
  echo "nixos-generate-config not found: run this on the NixOS machine you are adding." >&2
  exit 1
fi

# Generate first so a failure leaves nothing half-created.
hardware=$(nixos-generate-config --show-hardware-config)

cp -r "$hosts_dir/examples/$template" "$hosts_dir/$name"
printf '%s\n' "$hardware" >"$hosts_dir/$name/hardware-configuration.nix"
sed -i -E "s/^(\s*networking\.hostName = )\"[^\"]*\";/\1\"$name\";/" "$hosts_dir/$name/default.nix"

# The flake only sees files git knows about.
if git -C "$hosts_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$hosts_dir" add -N "$hosts_dir/$name"
fi

cat <<MSG
Created hosts/$name from the '$template' template.

Next:
  1. Edit hosts/$name/default.nix: pick the hardwareModules that match this
     machine (see hosts/README.md) and fill in anything marked in comments
     (NVIDIA bus IDs, GRUB disk on a BIOS machine).
  2. nix build /etc/nixos#nixosConfigurations.$name.config.system.build.toplevel
  3. sudo nixos-rebuild boot --flake /etc/nixos#$name   (then reboot)
MSG
