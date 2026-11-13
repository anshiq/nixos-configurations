# Template: desktop PC with an Intel CPU and integrated graphics, UEFI boot.
# Copy with hosts/new-host.sh. No battery, so the laptop module is left out.
{ hardwareModules, ... }:

{
  imports = [
    ./hardware-configuration.nix
    hardwareModules.boot-uefi
    hardwareModules.cpu-intel
    hardwareModules.gpu-intel
  ];

  networking.hostName = "desktop-intel";
}
