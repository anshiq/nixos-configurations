# NVIDIA GPU with the proprietary driver, for Wayland/Hyprland.
#
# Single-GPU machine: importing this module is enough.
# Hybrid laptop (Intel/AMD iGPU + NVIDIA): also set the PRIME bus IDs in the
# host (see hosts/examples/laptop-nvidia); the iGPU then drives the screen and
# the NVIDIA GPU is used on demand with `nvidia-offload <command>`.
#
# Find bus IDs with `lspci | grep -E 'VGA|3D'` (01:00.0 -> "PCI:1:0:0").
{ config, lib, ... }:

let
  prime = config.hardware.nvidia.prime;
  hybrid = prime.offload.enable || prime.sync.enable || prime.reverseSync.enable;
in
{
  hardware.graphics.enable = true;
  # The driver is chosen through the X server option even with no X session.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Required by Wayland compositors (DRM kernel mode setting).
    modesetting.enable = true;
    # Open kernel modules need a Turing (GTX 16xx / RTX 20xx) or newer GPU.
    # Set to false in the host for older cards (and pick a legacy `package`).
    open = lib.mkDefault true;
    nvidiaSettings = true;
    # Saves VRAM across suspend, fewer broken screens after resume.
    powerManagement.enable = lib.mkDefault true;
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
  }
  // lib.optionalAttrs (!hybrid) {
    # Right for a single NVIDIA GPU; on a hybrid laptop it would force every
    # app onto the dGPU, so it is left out there (offload sets it per command).
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };
}
