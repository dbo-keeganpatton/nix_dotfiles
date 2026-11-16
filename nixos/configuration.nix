{ config, lib, pkgs, ... }:
let

  unstable = import <nixos-unstable> {};

  # Herdr is an agent harness tool
  herdr = (builtins.getFlake "github:herdrdev/herdr/v0.8.2")
    .packages.${pkgs.system}.default;

  # Zen browser does not have an official package yet
  # so this flake work around is required
  zen-browser = (builtins.getFlake "github:youwen5/zen-browser-flake")
    .packages.${pkgs.system}.default;


  # Keybind GUI utility toggle by SUPER+i
  keybind-helper = pkgs.writeShellScriptBin "keybind-helper" ''
  CONFIG_PATH="$HOME/.config/hypr/hyprland.conf"
  grep '^bind =' "$CONFIG_PATH" | \
  sed -e 's/\$mainMod/SUPER/g' \
  -e 's/^bind[a-z]*\s*=\s*//g' \
  -e 's/,/  +  /g' \
  -e 's/,/  :  /g' | \
  ${pkgs.rofi}/bin/rofi -dmenu -i -p "󱕰 Keybinds" 
  '';

  custom-astronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "hyprland_kath";
  };

  # Time Determined Wallpapers
  constantWall = "/home/keegan/.config/waypaper/Wallpapers/26027867.jpg";
  morningWall   = "/home/keegan/.config/waypaper/Wallpapers/persona-3-rooftop-sunset.1920x1080.mp4";
  afternoonWall = "/home/keegan/.config/waypaper/Wallpapers/c7fd270208_final-fantasy-vii-buster-sword-live-wallpaper-wallsflow-com.mp4";
  eveningWall   = "/home/keegan/.config/waypaper/Wallpapers/oblivion-fireplace-pixel.1920x1080.mp4";
  nightWall     = "/home/keegan/.config/waypaper/Wallpapers/c7fd270208_final-fantasy-vii-buster-sword-live-wallpaper-wallsflow-com.mp4";


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

    # Feed the video directly to waypaper, specifying mpvpaper as the backend wrapper
    ${pkgs.waypaper}/bin/waypaper --backend mpvpaper --wallpaper "$CURRENT_WALLPAPER"
  '';


  # Audio-only player with a red bar equalizer rendered inline in Kitty.
  # mpv handles audio + terminal OSD. ffmpeg generates RGBA frames piped to a
  # Python sidecar that sends them via Kitty graphics protocol f=32 (true RGBA),
  # bypassing mpv's kitty VO which hardcodes f=24 (RGB, no transparency).
  mpv-play = pkgs.writeShellScriptBin "mpv-play" ''
    set -euo pipefail

    if [ "$#" -ne 1 ]; then
      echo "Usage: mpv-play <URL>" >&2
      exit 1
    fi

    URL=$(${unstable.yt-dlp}/bin/yt-dlp --no-warnings -f bestaudio/best \
      --extractor-args "youtube:player_client=android" \
      --get-url "$1" 2>/dev/null | head -1)

    cleanup() {
      printf '\033[?1049l\033[?25h\033[0m'
    }
    trap cleanup EXIT INT TERM

    printf '\033[?1049h\033[H\033[2J\033[?25l'

    env -u DISPLAY ${pkgs.mpv}/bin/mpv \
      --vo=kitty \
      --lavfi-complex='[aid1]showfreqs=mode=bar:ascale=log:fscale=lin:win_size=128:win_func=hann:colors=red|red:s=384x200,geq=r=r(X\,Y)*lt(mod(X\,6)\,5):g=0:b=0[vo]' \
      --osd-level=1 \
      -- "$URL"
  '';


in
{


  imports = [
    ./hardware-configuration.nix
    ./nix_modules/environment_variables.nix
    ./nix_modules/desktop_environment.nix
    ./nix_modules/networking.nix
    ./nix_modules/bluetooth.nix
    ./nix_modules/services.nix
    ./nix_modules/graphics.nix
    ./nix_modules/gaming.nix
    ./nix_modules/sound.nix
    (builtins.getFlake "https://pkgs.superlogical.com/rex/nix/preview.tar.gz").nixosModules.default
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];


  boot.loader.systemd-boot.enable                 = true;
  boot.loader.efi.canTouchEfiVariables            = true;
  boot.kernelParams                               = ["snd_intel_dspcfg.dsp_driver=3"];
  time.timeZone                                   = "America/Chicago";


  programs.firefox.enable                         = false;
  programs.hyprlock.enable                        = true;
  programs.thunar.enable                          = true; 	# File manager
  programs.light.enable                           = true;		# Brightness 


  security.polkit.enable                          = true;
  powerManagement.enable                          = true;		# Power Management


  users.users.keegan = {
    isNormalUser                                  = true;
    extraGroups = [
      "adbusers"
      "kvm"
      "networkmanager"
      "video"
      "audio"
      "wheel"
      "sudo"
      "rex"
    ];
    packages = with pkgs; [];
  };



  # System Packages
  environment.systemPackages = with pkgs; [
    python3Packages.pynvim        # Neovim Python Client 
    python3Packages.pip           # Python Package Manager
    phinger-cursors               # Custom Cursor
    keybind-helper                # Custom function for keybind ref popup utility
    custom-astronaut
    wl-clipboard                  # Wayland Copy/Paste Utility
    wf-recorder                   # Screen Recording Utility
    wireplumber                   # Audio Utility
    alsa-utils                    # Audio Utility
    pavucontrol                   # Audio Control GUI
    tree-sitter                   # Syntax Parser for Editor
    fastfetch                     # System Info Tool
    playerctl                     # Audio Utility
    grimblast                     # Screenshots
    hyprpaper                     # Wallpaper Utility
    hyprlock                      # Screen Locking
    hypridle                      # System Idle Daemon 
    vlc
    waypaper                      # Wallpaper Manager
    mpvpaper                      # Live Wallpaper Utility
    mpv                           # YT music player TUI
    mpv-play                      # Kitty-rendered audio player w/ red EQ
    luarocks                      # Lua Package Manager
    libreoffice                   # Mundane utilities
    rpi-imager                    # Raspberry Pi imager
    pciutils 		                  # PCI Utility
    google-chrome
    unstable.yt-dlp               # YT download tool
    zen-browser                   # Minimal Web Browser

    #->> Time of day wallpaper setting
    dynamicWallpaperScript

    #->> These packages are for linux-casefolding fix
    #->> to fix texture issues in Counter Strike Source
    inotify-tools
    libnotify
    parallel
    #->>

    #->> Packages specifically for Cyberpunk 2077 mod support
    protontricks                  # Linux gaming utility
    zenity                        # Linus gaming utility
    freefont_ttf                  # Required by WINE (Protontricks)
    liberation_ttf                # Required by WINE (Protontricks)
    freetype
    fontconfig
    libpng
    heroic
    #->>


    #->> Game dev
    godot
    android-studio
    #->>
  
    discord-ptb                   # discord chat
    gnome-calendar                # Calendar App
    starship                      # Command Line Prompt Customizer
    claude-code                   # CLI AI Coding agent
    herdr                         # Terminal multiplexer for coding agents
    python3                       # Python Runtime
    cmatrix			                  # Turbo Nerd Flex Tool
    zathura                       # Terminal Based PDF Utility
    gnumake                       # Build Automation for MAKE
    ripgrep                       # System Search Tool
    kubectl 
    kubernetes-helm
    unstable.neovim               # Text Editor
    unstable.circumflex           # TUI for browsing hackernews
    heroku                        # Deployment and Hosting Service CLI
    kalker                        # System Calculator
    waybar                        # Desktop Navbar
    lua5_1                        # Lua Runtime
    nodejs                        # Node Package Manager
    slurp                         # Screenshot helper utility
    unzip                         # Extraction Utility
    rustc                         # Rust runtime
    cargo                         # Rust Package Manager
    krita                         # Vector grapgic editor
    nmap                          # Network Application
    rofi                          # Wayland Window Switcher Utility
    contour                       # testing terminal
    kitty                         # Settle Terminal
    wofi                          # Menu GUI
    gimp
    btop-cuda                     # Btop Version for GPU monitoring
    hyprsunset                    # Night Light
    ffmpeg
    yazi                          # Command Line File Manager
    grim                          # Screenshot Utility
    tmux                          # Terminal Multiplexer
    wget                          # File downloader
    gcc                           # C Compiler
    fzf                           # Command Line Fuzzy Finder
    git                           # Version Control Tool
    bun                           # Javascript runtime
    fd                            # Alternative to Find Utility
    jq                            # CLI JSON Processor
  ];
  

  # Android
  programs.adb.enable = true;

  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];

  # Nix Specific
  nixpkgs.config.allowUnfree            = true;
  system.stateVersion                   = "25.11";

}

