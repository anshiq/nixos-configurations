# Running inside a virtual machine: guest agents (clipboard sharing, resizing)
# and software rendering when the VM has no GPU. Pick the hypervisor in the host:
#   desktop.vmGuest = "qemu";   # or "virtualbox" / "vmware"
{ config, lib, ... }:

{
  options.desktop.vmGuest = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "qemu"
        "virtualbox"
        "vmware"
      ]
    );
    default = null;
    description = "Hypervisor this machine runs under; enables its guest additions.";
  };

  config = lib.mkMerge [
    {
      hardware.graphics.enable = true;
      # No GPU in most VMs: let wlroots/Aquamarine fall back to llvmpipe and
      # avoid the hardware cursor plane, which VM display adapters get wrong.
      environment.sessionVariables = {
        WLR_RENDERER_ALLOW_SOFTWARE = "1";
        WLR_NO_HARDWARE_CURSORS = "1";
      };
    }
    (lib.mkIf (config.desktop.vmGuest == "qemu") {
      services.qemuGuest.enable = true;
      services.spice-vdagentd.enable = true;
    })
    (lib.mkIf (config.desktop.vmGuest == "virtualbox") {
      virtualisation.virtualbox.guest.enable = true;
    })
    (lib.mkIf (config.desktop.vmGuest == "vmware") {
      virtualisation.vmware.guest.enable = true;
    })
  ];
}
