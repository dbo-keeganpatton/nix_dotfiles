{ config, pkgs, ... }:

{

  programs.gamescope.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamemode.enable = true;
  programs.steam = {
    enable              = true;
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

}
