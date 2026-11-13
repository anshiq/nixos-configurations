# Intel integrated graphics (i915 / xe): Mesa plus VA-API hardware video
# decode/encode (browsers, screen recording).
{ pkgs, ... }:

{
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # Broadwell (2014) and newer
      vpl-gpu-rt # QuickSync via oneVPL, Tiger Lake / Gen12 and newer
    ];
  };
  # Pre-Broadwell iGPUs need intel-vaapi-driver instead of intel-media-driver.
}
