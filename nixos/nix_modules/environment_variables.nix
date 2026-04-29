{ config, pkgs, ... }:

{
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

}
