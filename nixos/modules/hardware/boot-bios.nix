# Legacy BIOS boot with GRUB, for machines without UEFI.
#
# The host must say which disk GRUB goes on, e.g. in hosts/<name>/default.nix:
#   boot.loader.grub.device = "/dev/sda";
# (NixOS refuses to build until it is set - that is intentional, a wrong guess
# here would leave the machine unbootable.)
#
# desktop/greeter and configuration.nix set `boot.loader.timeout = 0`, which on
# GRUB hides the menu; hold Shift while booting to get it back.
{ ... }:

{
  boot.loader.grub.enable = true;
}
