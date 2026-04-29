{ config, lib, pkgs, ... }:

let

  # Unstable branch for Nvim
  unstable = import <nixos-unstable> {};

  # Custom SDDM login Screen with animated anime girl
  custom-astronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "hyprland_kath";
  };

  # as a helper tool using SUPER+i 
  keybind-helper = pkgs.writeShellScriptBin "keybind-helper" ''
  CONFIG_PATH="$HOME/.config/hypr/hyprland.conf"
  grep '^bind =' "$CONFIG_PATH" | \
  sed -e 's/\$mainMod/SUPER/g' \
  -e 's/^bind[a-z]*\s*=\s*//g' \
  -e 's/,/  +  /g' \
  -e 's/,/  :  /g' | \
  ${pkgs.rofi}/bin/rofi -dmenu -i -p "󱕰 Keybinds" 
  '';

in

{


  imports = [ 
    ./hardware-configuration.nix
    ./graphics.nix
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Bluetooth Config
  services.blueman.enable                         = true;
  hardware.bluetooth = {
    enable                                        = true;
    powerOnBoot                                   = true;
  };



  programs.steam = {
    enable = true;
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



  # Bootloader Configs
  boot.loader.systemd-boot.enable                 = true;
  boot.loader.efi.canTouchEfiVariables            = true;
  boot.kernelParams                               = ["snd_intel_dspcfg.dsp_driver=3"];

  # Networking (Use nmcli)
  networking.hostName                             = "eyelady_core"; 
  networking.networkmanager.enable                = true;
  networking.firewall.enable                      = true;

  # Homelab Service Hosts
  networking.hosts = {
    "192.168.0.7"                                 = ["grafana.local"];	
  };

  # System Time Zone.
  time.timeZone                                   = "America/Chicago";

  # Desktop Environment Setup 
  services.displayManager.sddm = {
    # Login Screen
    enable                                        = true;
    wayland.enable                                = true; 
    theme                                         = "sddm-astronaut-theme";
    extraPackages = with pkgs; [
      custom-astronaut
      kdePackages.qtmultimedia
      kdePackages.qtsvg
      kdePackages.qt5compat
    ];
  };


  services.displayManager.defaultSession          = "hyprland";
  programs.hyprland.enable                        = true;
  programs.thunar.enable                          = true; 	# File manager
  services.gvfs.enable                            = true;		# Trash Bin
  services.tumbler.enable                         = true;		# Thumbnails


  # This is for auto locking the screen
  services.logind.settings.Login.HandleLidSwitch  = "suspend"; 
  programs.hyprlock.enable                        = true;
  services.hypridle.enable                        = true;
  services.dbus.enable                            = true;
  security.polkit.enable                          = true;


  # System Basics 
  services.libinput.enable                        = true;		# Touchpad
  services.printing.enable                        = true;		# Printing
  programs.light.enable                           = true;		# Brightness 
  services.openssh.enable                         = true;		# SSH Daemon
  powerManagement.enable                          = true;		# Power Management

  # Internet Browser
  programs.firefox.enable                         = true;

  # System Users 
  users.users.keegan = {
    isNormalUser                                  = true;
    extraGroups = [ 
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
    custom-astronaut              # SDDM Login Screen
    phinger-cursors               # Custom Cursor
    keybind-helper                # Custom function for keybind ref popup utility
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
    rpi-imager                    # Raspberry Pi imager
    pciutils 		                  # PCI Utility
    google-chrome

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


  
    starship                      # Command Line Prompt Customizer
    python3                       # Python Runtime
    cmatrix			                  # Turbo Nerd Flex Tool
    zathura                       # Terminal Based PDF Utility
    gnumake                       # Build Automation for MAKE
    ripgrep                       # System Search Tool
    unstable.neovim               # Text Editor
    heroku                        # Deployment and Hosting Service CLI
    kalker                        # System Calculator
    waybar                        # Desktop Navbar
    lua5_1                        # Lua Runtime
    nodejs                        # Node Package Manager
    steam                         # Video Games
    steam-run                     # FHS steam hack
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


  # Wayland Variables
  environment.sessionVariables = {
    XDG_SESSION_TYPE                    = "wayland";
    XDG_CURRENT_DESKTOP                 = "Hyprland";
    MOZ_ENABLE_WAYLAND                  = "1";
    QT_QPA_PLATFORM                     = "wayland";
    SDL_VIDEODRIVER                     = "wayland";
    GDK_BACKEND                         = "wayland";

    # Cursor Configs
    XCURSOR_THEME                       = "phinger-cursors-light";
    XCURSOR_SIZE                        = "24";
    HYPRCURSOR_SIZE                     = "24";
  };


  # Sound
  security.rtkit.enable = true;
  services.pulseaudio.enable = false;
  hardware.enableAllFirmware = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber = { enable = true; };
  };

 
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Fonts
  fonts.packages                        = [ pkgs.nerd-fonts.jetbrains-mono ];

  # Nix Specific
  nixpkgs.config.allowUnfree            = true;
  system.stateVersion                   = "25.11";

}

