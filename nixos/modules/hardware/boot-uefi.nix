# UEFI boot with systemd-boot. The default for any machine made in the last
# decade; use boot-bios.nix instead on a legacy-BIOS machine.
{ ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
