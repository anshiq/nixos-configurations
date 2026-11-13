# Running inside a virtual machine: guest agents (clipboard sharing, resizing).
# Pick the hypervisor in the host:
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
