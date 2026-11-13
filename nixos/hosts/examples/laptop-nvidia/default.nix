# Template: hybrid laptop - Intel CPU + iGPU for the screen, NVIDIA dGPU used
# on demand (`nvidia-offload <command>`), UEFI boot. Copy with hosts/new-host.sh,
# then fill in the PRIME bus IDs below.
{ hardwareModules, ... }:

{
  imports = [
    ./hardware-configuration.nix
    hardwareModules.boot-uefi
    hardwareModules.cpu-intel
    hardwareModules.gpu-intel
    hardwareModules.gpu-nvidia
    hardwareModules.laptop
  ];

  networking.hostName = "laptop-nvidia";

  hardware.nvidia = {
    # false for pre-Turing cards (GTX 10xx and older); then also pick a legacy
    # driver, e.g. package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
    # open = false;

    # Battery saver: powers the dGPU down when idle (Turing and newer).
    powerManagement.finegrained = true;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # provides `nvidia-offload`
      };
      # From `lspci | grep -E 'VGA|3D'`: "00:02.0" -> "PCI:0:2:0".
      # For an AMD iGPU use amdgpuBusId instead of intelBusId.
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}
