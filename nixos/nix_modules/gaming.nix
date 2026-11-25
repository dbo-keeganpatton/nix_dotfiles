{ config, pkgs, ... }:

{

  programs.gamescope.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamemode.enable = true;
  programs.steam = {
    enable              = true;

    package = pkgs.steam.override {
      extraEnv = {
        __NV_PRIME_RENDER_OFFLOAD = "1";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        __VK_LAYER_NV_optimus = "NVIDIA_only";
      };
      extraArgs = "--enable-features=UseOzonePlatform --ozone-platform=wayland";
    };

    protontricks.enable = true;
    extraPackages = with pkgs; [
      wineWow64Packages.stable
      winetricks
      freetype
      libjpeg
      libpng
      zenity
      zlib
      yad
    ];
  };

  environment.systemPackages = with pkgs; [
    heroic                         # Game launcher

    #->> Cyberpunk 2077 mod support
    protontricks
    zenity
    freefont_ttf
    liberation_ttf
    freetype
    fontconfig
    libpng
    #->>

    #->> CS:S linux-casefolding fix
    inotify-tools
    libnotify
    parallel
    #->>

    #->> Game dev
    godot
    android-studio
    #->>
  ];

}
