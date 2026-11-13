# AMD CPU: KVM and microcode updates. nixos-generate-config usually writes the
# same thing into hardware-configuration.nix; these are mkDefault so they only
# fill in when it did not (e.g. a config generated inside a VM).
{ config, lib, ... }:

{
  boot.kernelModules = lib.mkDefault [ "kvm-amd" ];
  hardware.enableRedistributableFirmware = lib.mkDefault true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
