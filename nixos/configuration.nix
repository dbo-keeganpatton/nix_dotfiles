{ config, lib, pkgs, pkgs-unstable, inputs, ... }:
let

  unstable = pkgs-unstable;

  # Herdr is an agent harness tool
  herdr = inputs.herdr.packages.${pkgs.system}.default;

  zen-browser = inputs.zen-browser-flake.packages.${pkgs.system}.default;

in
{


  imports = [
    ./packages
    ./hardware-configuration.nix
    ./nix_modules/environment_variables.nix
    ./nix_modules/desktop_environment.nix
    ./nix_modules/networking.nix
    ./nix_modules/bluetooth.nix
    ./nix_modules/services.nix
    ./nix_modules/graphics.nix
    ./nix_modules/gaming.nix
    ./nix_modules/sound.nix
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
      "plugdev"
    ];
    packages = with pkgs; [];
  };



  # System Packages
  environment.systemPackages = with pkgs; [
    python3Packages.pynvim        # Neovim Python Client
    python3Packages.pip           # Python Package Manager
    phinger-cursors               # Custom Cursor
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
    unstable.mpv                           # YT music player TUI
    luarocks                      # Lua Package Manager
    libreoffice                   # Mundane utilities
    rpi-imager                    # Raspberry Pi imager
    pciutils 		                  # PCI Utility
    google-chrome
    unstable.yt-dlp               # YT download tool
    zen-browser                   # Minimal Web Browser

    #->> Corne keyboard tooling
    vial
    qmk-udev-rules

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
    unstable.pi-coding-agent      # Coding agent CLI
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
