{ config, pkgs, ... }:

{
  networking.hostName                    = "eyelady_core"; 
  networking.networkmanager.enable       = true;
  networking.firewall.enable             = true;
  services.openssh.enable                = true;		

  # Homelab Service Hosts
  networking.hosts = {
    "192.168.0.7"                        = ["grafana.local"];	
  };


}
