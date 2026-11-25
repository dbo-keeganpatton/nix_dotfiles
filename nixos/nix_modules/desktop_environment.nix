{ config, pkgs, ... }:

let
  custom-astronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "hyprland_kath";
  };
in
{

  environment.systemPackages = with pkgs; [
    custom-astronaut

    #->> Hyprland desktop
    hyprpaper              # Wallpaper daemon
    waypaper               # Wallpaper manager GUI
    mpvpaper               # Live wallpaper (mpv backend)
    waybar                 # Status bar
    hyprsunset             # Night light
    wofi                   # App launcher
    rofi                   # Window switcher / keybind popup
    hypridle               # Idle daemon (re-exported for PATH)

    #->> Screenshots / screen capture
    grimblast
    grim
    slurp
    wf-recorder

    #->> Wayland utilities
    wl-clipboard           # Clipboard
    phinger-cursors        # Cursor theme

    #->> Terminals
    kitty
    contour
  ];

  services.displayManager.sddm = {
    enable         = true;
    wayland.enable = true;
    theme          = "sddm-astronaut-theme";

    extraPackages = with pkgs; [
      custom-astronaut
      kdePackages.qtmultimedia
      kdePackages.qtsvg
      kdePackages.qt5compat
    ];
  };

  services.displayManager.defaultSession = "hyprland";
  programs.hyprland.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

}
