# Laptop: battery state over DBus. The bar's battery widget, the low-battery
# notifier and the Power page of the settings app all read it, and hypridle
# only dims/suspends on battery (desktop/scripts/on-battery.sh).
# A desktop PC simply leaves this module out.
{ ... }:

{
  # Battery/AC state over DBus for the bar and settings app (Quickshell UPower).
  services.upower.enable = true;
}
