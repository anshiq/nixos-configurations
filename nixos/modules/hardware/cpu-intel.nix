# Intel CPU: KVM, microcode updates and thermald. nixos-generate-config usually
# writes the first two into hardware-configuration.nix; these are mkDefault so
# they only fill in when it did not.
{ config, lib, ... }:

{
  boot.kernelModules = lib.mkDefault [ "kvm-intel" ];
  hardware.enableRedistributableFirmware = lib.mkDefault true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # Keeps Intel CPUs under their thermal limit without throttling hard.
  services.thermald.enable = lib.mkDefault true;
}
