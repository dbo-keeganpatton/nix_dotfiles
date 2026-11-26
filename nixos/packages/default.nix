{ config, pkgs, pkgs-unstable, ... }:

let
  unstable = pkgs-unstable;

  constantWall  = "/home/keegan/.config/waypaper/Wallpapers/peaceful-campfire-moewalls-com.mp4";
  morningWall   = "/home/keegan/.config/waypaper/Wallpapers/persona-3-rooftop-sunset.1920x1080.mp4";
  afternoonWall = "/home/keegan/.config/waypaper/Wallpapers/c7fd270208_final-fantasy-vii-buster-sword-live-wallpaper-wallsflow-com.mp4";
  eveningWall   = "/home/keegan/.config/waypaper/Wallpapers/oblivion-fireplace-pixel.1920x1080.mp4";
  nightWall     = "/home/keegan/.config/waypaper/Wallpapers/c7fd270208_final-fantasy-vii-buster-sword-live-wallpaper-wallsflow-com.mp4";

  # Keybind reference popup — toggled via SUPER+i
  keybind-helper = pkgs.writeShellScriptBin "keybind-helper" ''
  CONFIG_PATH="$HOME/.config/hypr/hyprland.conf"
  grep '^bind =' "$CONFIG_PATH" | \
  sed -e 's/\$mainMod/SUPER/g' \
  -e 's/^bind[a-z]*\s*=\s*//g' \
  -e 's/,/  +  /g' \
  -e 's/,/  :  /g' | \
  ${pkgs.rofi}/bin/rofi -dmenu -i -p "󱕰 Keybinds"
  '';

  dynamicWallpaperScript = pkgs.writeShellScriptBin "dynamic-wallpaper" ''
    HOUR=$(${pkgs.coreutils}/bin/date +%H)

    if [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 12 ]; then
        CURRENT_WALLPAPER="${constantWall}"
    elif [ "$HOUR" -ge 12 ] && [ "$HOUR" -lt 18 ]; then
        CURRENT_WALLPAPER="${constantWall}"
    elif [ "$HOUR" -ge 18 ] && [ "$HOUR" -lt 21 ]; then
        CURRENT_WALLPAPER="${constantWall}"
    else
        CURRENT_WALLPAPER="${constantWall}"
    fi

    ${pkgs.waypaper}/bin/waypaper --backend mpvpaper --wallpaper "$CURRENT_WALLPAPER"
  '';

  # Audio-only player with a lavender/yellow bar equalizer drawn inline in
  # Kitty (or any terminal with the Kitty graphics protocol). The stream is
  # fetched once by ffmpeg; mpv plays it and reports its position so the bars
  # stay in sync. See mpv-play.py for details.
  mpv-play = pkgs.writeTextFile {
    name = "mpv-play";
    executable = true;
    destination = "/bin/mpv-play";
    text = builtins.replaceStrings
      [ "#!/usr/bin/env python3" "@ffmpeg@" "@ffprobe@" "@mpv@" "@ytdlp@" ]
      [ "#!${pkgs.python3.withPackages (ps: [ ps.numpy ])}/bin/python3"
        "${pkgs.ffmpeg}/bin/ffmpeg"
        "${pkgs.ffmpeg}/bin/ffprobe"
        "${unstable.mpv}/bin/mpv"
        "${unstable.yt-dlp}/bin/yt-dlp" ]
      (builtins.readFile ./mpv-play.py);
  };

in
{
  environment.systemPackages = [
    keybind-helper
    dynamicWallpaperScript
    mpv-play
  ];
}
