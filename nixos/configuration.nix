{ config, lib, pkgs, ... }:
let

  unstable = import <nixos-unstable> {};

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
  morningWall   = "/home/keegan/.config/waypaper/Wallpapers/morning_wallpaper.mp4";
  afternoonWall = "/home/keegan/.config/waypaper/Wallpapers/day_wallpaper.mp4";
  eveningWall   = "/home/keegan/.config/waypaper/Wallpapers/evening_wallpaper.mp4";
  nightWall     = "/home/keegan/.config/waypaper/Wallpapers/night_wallpaper.mp4";


  dynamicWallpaperScript = pkgs.writeShellScriptBin "dynamic-wallpaper" ''
    HOUR=$(${pkgs.coreutils}/bin/date +%H)

    if [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 12 ]; then
        CURRENT_WALLPAPER="${morningWall}"
    elif [ "$HOUR" -ge 12 ] && [ "$HOUR" -lt 18 ]; then
        CURRENT_WALLPAPER="${afternoonWall}"
    elif [ "$HOUR" -ge 18 ] && [ "$HOUR" -lt 21 ]; then
        CURRENT_WALLPAPER="${eveningWall}"
    else
        CURRENT_WALLPAPER="${nightWall}"
    fi

    # Feed the video directly to waypaper, specifying mpvpaper as the backend wrapper
    ${pkgs.waypaper}/bin/waypaper --backend mpvpaper --wallpaper "$CURRENT_WALLPAPER"
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
    ./nix_modules/ai.nix
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];


  boot.loader.systemd-boot.enable                 = true;
  boot.loader.efi.canTouchEfiVariables            = true;
  boot.kernelParams                               = ["snd_intel_dspcfg.dsp_driver=3"];
  time.timeZone                                   = "America/Chicago";


  programs.firefox.enable                         = true;
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
    waypaper                      # Wallpaper Manager
    mpvpaper                      # Live Wallpaper Utility
    luarocks                      # Lua Package Manager
    libreoffice                   # Mundane utilities
    rpi-imager                    # Raspberry Pi imager
    pciutils 		                  # PCI Utility
    google-chrome
    yt-dlp                        # YT download tool

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
  
    starship                      # Command Line Prompt Customizer
    claude-code                   # CLI AI Coding agent
    python3                       # Python Runtime
    cmatrix			                  # Turbo Nerd Flex Tool
    zathura                       # Terminal Based PDF Utility
    gnumake                       # Build Automation for MAKE
    ripgrep                       # System Search Tool
    kubectl 
    kubernetes-helm
    unstable.neovim               # Text Editor
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
    alacritty                     # GPU buffed terminal
    kitty                         # I shouldn't even have this shit here, literally just for pets.nvim
    wofi                          # Menu GUI
    btop-cuda                     # Btop Version for GPU monitoring
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

