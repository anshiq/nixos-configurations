# The original machine: AMD Ryzen 3 3250U laptop (Vega graphics), UEFI.
{ hardwareModules, ... }:

{
  imports = [
    ./hardware-configuration.nix
    hardwareModules.boot-uefi
    hardwareModules.cpu-amd
    hardwareModules.gpu-amd
    hardwareModules.laptop
  ];

  # Kept as "nixos" (not "laptop-amd") so `nixos-rebuild --flake /etc/nixos`
  # with no #name keeps finding it; flake.nix also exposes it as `nixos`.
  networking.hostName = "nixos";
}
