{ config, pkgs, ... }:

{
  services.gvfs.enable                            = true;		# Trash Bin
  services.tumbler.enable                         = true;		# Thumbnails
  services.hypridle.enable                        = true;
  services.dbus.enable                            = true;
  services.libinput.enable                        = true;		# Touchpad
  services.printing.enable                        = true;		# Printing

  services.logind.settings.Login.HandleLidSwitch  = "suspend"; 
}
