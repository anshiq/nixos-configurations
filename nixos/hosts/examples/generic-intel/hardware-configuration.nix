# PLACEHOLDER so this template evaluates and can be test-built. hosts/new-host.sh
# replaces it with the real `nixos-generate-config` output of the new machine.
# Never rebuild a machine with this file: the disks below do not exist.
{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
