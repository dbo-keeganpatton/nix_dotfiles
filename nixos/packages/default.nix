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

  # Audio-only player with a red bar equalizer rendered inline in Kitty.
  # mpv handles audio. ffmpeg generates RGBA frames read by a Python sidecar
  # that sends them via Kitty graphics protocol f=32 (true RGBA), bypassing
  # mpv's kitty VO which hardcodes f=24 (RGB, no transparency).
  mpv-play-renderer = pkgs.writeTextFile {
    name = "mpv-play-renderer";
    executable = true;
    destination = "/bin/mpv-play-renderer";
    text = ''
      #!${pkgs.python3}/bin/python3
      import sys, os, fcntl, termios, struct, base64, subprocess, signal, tempfile, glob, time

      ESC = b"\033"
      ST  = b"\033\\"
      FFMPEG = "${pkgs.ffmpeg}/bin/ffmpeg"

      def term_info():
          try:
              buf = struct.pack("HHHH", 0, 0, 0, 0)
              r = fcntl.ioctl(sys.stdout.fileno(), termios.TIOCGWINSZ, buf)
              rows, cols, xpix, ypix = struct.unpack("HHHH", r)
              if xpix == 0 or ypix == 0:
                  xpix, ypix = cols * 8, rows * 16
              return cols, rows, xpix, ypix
          except Exception:
              return 80, 24, 640, 384

      def main():
          if len(sys.argv) < 2:
              sys.stderr.write("usage: mpv-play-renderer <audio-url>\n")
              sys.exit(1)
          url = sys.argv[1]

          cols, rows, xpix, ypix = term_info()
          cell_w = max(1, xpix // max(1, cols))
          cell_h = max(1, ypix // max(1, rows))
          viz_w = cols * cell_w
          viz_h = rows * cell_h

          # One visual bar per showfreqs frequency bin (nb_freq = win_size/2),
          # so each bar is a flat-topped rectangle instead of a jagged slice.
          win_size   = 64
          num_bars   = win_size // 2
          bar_period = max(8, viz_w // num_bars)
          gap_width  = max(2, bar_period // 5)
          bar_width  = bar_period - gap_width

          fc = (
              f"[0:a]showfreqs=mode=bar:ascale=log:fscale=lin:"
              f"win_size={win_size}:win_func=hann:colors=red|red:s={viz_w}x{viz_h},"
              f"format=rgba,"
              f"geq=r='r(X,Y)':g=0:b=0:"
              f"a='255*lt(mod(X,{bar_period}),{bar_width})*gt(r(X,Y),16)'[v]"
          )

          cmd = [
              FFMPEG, "-hide_banner", "-loglevel", "error",
              "-re", "-i", url,
              "-filter_complex", fc,
              "-map", "[v]", "-r", "30",
              "-f", "rawvideo", "-pix_fmt", "rgba", "-",
          ]

          shm = "/dev/shm" if os.path.isdir("/dev/shm") else tempfile.gettempdir()
          pid = os.getpid()
          prefix = f"mpvplay-{pid}-"

          def sweep_stale(max_age=1.0):
              now = time.time()
              for p in glob.glob(os.path.join(shm, prefix + "*.rgba")):
                  try:
                      if now - os.path.getmtime(p) > max_age:
                          os.unlink(p)
                  except OSError:
                      pass

          proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
          frame_bytes = viz_w * viz_h * 4
          out = sys.stdout.buffer

          try:
              out.write(b"\033[1;1H")
              out.flush()
          except (BrokenPipeError, OSError):
              return

          frame_idx = 0
          try:
              while True:
                  data = bytearray()
                  while len(data) < frame_bytes:
                      try:
                          chunk = proc.stdout.read(frame_bytes - len(data))
                      except (OSError, ValueError):
                          return
                      if not chunk:
                          return
                      data += chunk

                  try:
                      fd, path = tempfile.mkstemp(prefix=prefix, suffix=".rgba", dir=shm)
                  except OSError:
                      sweep_stale(max_age=0.0)
                      try:
                          fd, path = tempfile.mkstemp(prefix=prefix, suffix=".rgba", dir=shm)
                      except OSError:
                          continue
                  try:
                      os.write(fd, bytes(data))
                  finally:
                      os.close(fd)

                  p64 = base64.standard_b64encode(path.encode()).decode("ascii")
                  keys = f"a=T,q=2,f=32,s={viz_w},v={viz_h},i=1,p=1,C=1,t=t"
                  try:
                      out.write(b"\033[1;1H")
                      out.write(ESC + b"_G" + keys.encode("ascii") + b";" + p64.encode("ascii") + ST)
                      out.flush()
                  except (BrokenPipeError, OSError):
                      try: os.unlink(path)
                      except OSError: pass
                      return

                  frame_idx += 1
                  if frame_idx % 60 == 0:
                      sweep_stale()
          finally:
              try:
                  proc.terminate()
                  proc.wait(timeout=2)
              except subprocess.TimeoutExpired:
                  try: proc.kill()
                  except Exception: pass
              except Exception:
                  pass
              sweep_stale(max_age=0.0)

      if __name__ == "__main__":
          signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
          try:
              signal.signal(signal.SIGPIPE, signal.SIG_DFL)
          except (AttributeError, ValueError):
              pass
          main()
    '';
  };

  mpv-play = pkgs.writeShellScriptBin "mpv-play" ''
    set -euo pipefail

    if [ "$#" -ne 1 ]; then
      echo "Usage: mpv-play <URL>" >&2
      exit 1
    fi

    URL=$(${unstable.yt-dlp}/bin/yt-dlp --no-warnings -f bestaudio/best \
      --extractor-args "youtube:player_client=android" \
      --get-url "$1" 2>/dev/null | head -1)

    if [ -z "$URL" ]; then
      echo "mpv-play: failed to resolve audio URL" >&2
      exit 1
    fi

    MPV_PID=""
    cleanup() {
      if [ -n "$MPV_PID" ]; then
        kill "$MPV_PID" 2>/dev/null || true
        wait "$MPV_PID" 2>/dev/null || true
      fi
      # Remove kitty graphics image id 1 + any lingering placements.
      printf '\033_Ga=d,d=i,i=1\033\\'
      printf '\033[?1049l\033[?25h\033[0m'
    }
    trap cleanup EXIT INT TERM

    printf '\033[?1049h\033[H\033[2J\033[?25l'

    env -u DISPLAY ${unstable.mpv}/bin/mpv \
      --no-video --vo=null --no-terminal --quiet --idle=no \
      --input-default-bindings=no --input-vo-keyboard=no \
      -- "$URL" >/dev/null 2>&1 &
    MPV_PID=$!

    ${mpv-play-renderer}/bin/mpv-play-renderer "$URL"
  '';

in
{
  environment.systemPackages = [
    keybind-helper
    dynamicWallpaperScript
    mpv-play
  ];
}
