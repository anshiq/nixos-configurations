# Template: Intel machine (laptop, desktop or server), UEFI boot, CLI only.
# Copy with hosts/new-host.sh. For a BIOS machine swap boot-uefi for boot-bios
# and set boot.loader.grub.device; for AMD use cpu-amd; for a VM add vm-guest
# and `desktop.vmGuest = "qemu";`.
{ hardwareModules, ... }:

{
  imports = [
    ./hardware-configuration.nix
    hardwareModules.boot-uefi
    hardwareModules.cpu-intel
  ];

  networking.hostName = "generic-intel";
}
