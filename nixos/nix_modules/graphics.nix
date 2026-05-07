{ config, pkgs, ... }:

{

  # Enable 32bit support for steam to work
  hardware.graphics = {
    enable                            = true;
    enable32Bit                       = true; 
  };

  # Nvidia configs
  services.xserver.videoDrivers       = ["nvidia" "modesetting"];
  hardware.nvidia.open                = true;
  hardware.nvidia.modesetting.enable  = true;

  hardware.nvidia.prime = {
    offload.enable                    = true;	  
    intelBusId                        = "PCI:0@0:2:0";
    nvidiaBusId                       = "PCI:1@0:0:0";
  };

}
