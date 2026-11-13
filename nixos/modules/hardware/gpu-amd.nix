# AMD GPU (amdgpu, in the kernel; Mesa does the rest).
{ lib, ... }:

{
  hardware.graphics.enable = true;

  # amdgpu is deliberately NOT loaded in the initrd (hardware.amdgpu.initrd).
  # Measured 2026-11-11 on a Ryzen 3 3250U: loading the module costs ~4s of
  # kernel CPU wherever it happens. In the initrd that ran serially (initrd
  # 2.8s -> 6.5s) and pulled all AMD firmware in (initrd 28M -> 61M); loaded by
  # udev after switch-root it overlaps with other boot work. A fast machine
  # can set this to true for a flicker-free early console.
  hardware.amdgpu.initrd.enable = lib.mkDefault false;
}
