{ config, pkgs, ... }:

{

  security.rtkit.enable       = true;
  services.pulseaudio.enable  = false;
  hardware.enableAllFirmware  = true;
  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;
    pulse.enable      = true;
    jack.enable       = true;
    wireplumber = { enable = true; };
  };

  environment.systemPackages = with pkgs; [
    wireplumber    # Audio session manager
    alsa-utils     # ALSA CLI tools
    pavucontrol    # PulseAudio volume control GUI
    playerctl      # Media player control
  ];

}
