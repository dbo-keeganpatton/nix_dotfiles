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
    tree-sitter                   # Syntax Parser for Editor
    fastfetch                     # System Info Tool
    vlc
    unstable.mpv                  # Media player
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

    discord-ptb                   # discord chat
    gnome-calendar                # Calendar App
    starship                      # Command Line Prompt Customizer
    unstable.claude-code          # CLI AI Coding agent
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
    lua5_1                        # Lua Runtime
    nodejs                        # Node Package Manager
    unzip                         # Extraction Utility
    rustc                         # Rust runtime
    cargo                         # Rust Package Manager
    krita                         # Vector graphic editor
    nmap                          # Network Application
    gimp
    btop-cuda                     # Btop Version for GPU monitoring
    ffmpeg
    yazi                          # Command Line File Manager
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
