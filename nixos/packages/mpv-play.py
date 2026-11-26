#!/usr/bin/env python3
"""mpv-play: play a song's audio with mpv and draw a bar equalizer in the terminal.

Pipeline (the stream is fetched exactly once):

    yt-dlp  -> resolves the page URL to a direct audio URL (skipped for local files)
    ffmpeg  -> decodes it to raw PCM on stdout
    python  -> copies the PCM into mpv's stdin, keeping a mono copy in a ring buffer
    mpv     -> plays the audio and reports its playback position over its IPC socket

Every frame, the spectrum is computed from the ring buffer at mpv's *current*
playback position, so the bars stay in sync with what you hear and freeze when
paused. Frames are drawn with numpy and sent with the Kitty graphics protocol as
32-bit RGBA, so the gaps between bars are truly transparent.
"""

import base64
import fcntl
import glob
import json
import os
import re
import select
import shutil
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import termios
import threading
import time
import tty
import unicodedata

import numpy as np


def _tool(path, name):
    # Nix substitutes absolute store paths; fall back to $PATH when run unbuilt.
    return shutil.which(name) if path.startswith("@") else path


FFMPEG = _tool("@ffmpeg@", "ffmpeg")
FFPROBE = _tool("@ffprobe@", "ffprobe")
MPV = _tool("@mpv@", "mpv")
YTDLP = _tool("@ytdlp@", "yt-dlp")

# ── Look ────────────────────────────────────────────────────────────────────
FILL = (181, 160, 240)        # lavender bar body
BORDER = (255, 214, 0)        # yellow bar outline
BAR_CELLS = 6                 # target bar period (bar + gap), in terminal cells
MIN_BARS, MAX_BARS = 10, 48
GAP_FRACTION = 0.28           # share of each bar period left transparent

# ── Audio analysis ─────────────────────────────────────────────────────────
RATE = 48000
CHANNELS = 2
FFT_SIZE = 4096
F_LO, F_HI = 40.0, 16000.0
RANGE_DB = 48.0               # dynamic range mapped onto the bar height
FALL_PER_S = 1.8              # how fast bars drop (full heights per second)
PEAK_DECAY_DB_PER_S = 4.0     # auto-gain release
FPS = 30
RING_SECONDS = 60

SHM = "/dev/shm" if os.path.isdir("/dev/shm") else tempfile.gettempdir()
# Kitty only reads (and then deletes) t=t files whose name contains this marker.
FRAME_PREFIX = f"tty-graphics-protocol-mpv-play-{os.getpid()}-"
IMAGE_ID = 1


class Fatal(Exception):
    pass


# ── Source resolution ──────────────────────────────────────────────────────
def resolve(arg):
    """Return (input, title, duration, headers) for ffmpeg."""
    if os.path.exists(arg):
        duration = None
        try:
            out = subprocess.run(
                [FFPROBE, "-v", "error", "-show_entries", "format=duration",
                 "-of", "default=nw=1:nk=1", arg],
                capture_output=True, text=True, timeout=10).stdout.strip()
            duration = float(out)
        except (ValueError, subprocess.SubprocessError, OSError):
            pass
        return arg, os.path.basename(arg), duration, {}

    sys.stderr.write("mpv-play: resolving…\r")
    sys.stderr.flush()
    proc = subprocess.run(
        [YTDLP, "--no-warnings", "--no-playlist", "-f", "bestaudio/best", "-J", arg],
        capture_output=True, text=True)
    sys.stderr.write("\r\033[2K")
    sys.stderr.flush()
    if proc.returncode != 0:
        msg = proc.stderr.strip().splitlines()
        raise Fatal("could not resolve URL" + (f": {msg[-1]}" if msg else ""))
    info = json.loads(proc.stdout)
    fmt = info
    if "url" not in info:
        fmts = info.get("requested_formats") or []
        audio = [f for f in fmts if f.get("acodec") not in (None, "none")]
        if not audio:
            raise Fatal("yt-dlp returned no audio stream")
        fmt = audio[0]
    return (fmt["url"], info.get("title") or arg, info.get("duration"),
            fmt.get("http_headers") or info.get("http_headers") or {})


# ── Shared sample buffer ───────────────────────────────────────────────────
class Ring:
    def __init__(self, seconds):
        self.size = RATE * seconds
        self.data = np.zeros(self.size, np.float32)
        self.total = 0
        self.lock = threading.Lock()

    def write(self, x):
        with self.lock:
            n = len(x)
            start = self.total % self.size
            end = start + n
            if end <= self.size:
                self.data[start:end] = x
            else:
                k = self.size - start
                self.data[start:] = x[:k]
                self.data[:n - k] = x[k:]
            self.total += n

    def read(self, end, n):
        """Samples [end-n, end), or None if they are not (or no longer) buffered."""
        with self.lock:
            if end > self.total or end - n < max(0, self.total - self.size):
                return None
            return self.data[np.arange(end - n, end) % self.size]


def feed(ff, mpv, ring, state):
    """Copy ffmpeg's PCM into mpv while mirroring a mono copy into the ring."""
    src, dst = ff.stdout.fileno(), mpv.stdin.fileno()
    frame = 2 * CHANNELS
    rem = b""
    try:
        while True:
            data = os.read(src, 65536)
            if not data:
                break
            data = rem + data
            cut = len(data) - len(data) % frame
            rem = data[cut:]
            if not cut:
                continue
            chunk = data[:cut]
            pcm = np.frombuffer(chunk, np.int16).reshape(-1, CHANNELS)
            ring.write(pcm.mean(axis=1, dtype=np.float32) / 32768.0)
            state["got_audio"] = True
            view = memoryview(chunk)
            while view:  # blocks while mpv is paused / its buffer is full
                view = view[os.write(dst, view):]
    except OSError:
        pass
    finally:
        try:
            mpv.stdin.close()
        except OSError:
            pass


# ── mpv control ────────────────────────────────────────────────────────────
class MpvIPC(threading.Thread):
    def __init__(self, path, proc):
        super().__init__(daemon=True)
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        for _ in range(100):
            if proc.poll() is not None:
                raise Fatal("mpv exited during startup")
            try:
                self.sock.connect(path)
                break
            except OSError:
                time.sleep(0.05)
        else:
            raise Fatal("could not connect to mpv's IPC socket")
        self.wlock = threading.Lock()
        self.pos = None
        self.pos_t = 0.0
        self.paused = False
        self.volume = 100.0
        self.muted = False
        for i, prop in enumerate(("time-pos", "pause", "volume", "mute"), 1):
            self.command("observe_property", i, prop)

    def command(self, *args):
        line = json.dumps({"command": list(args)}).encode() + b"\n"
        try:
            with self.wlock:
                self.sock.sendall(line)
        except OSError:
            pass

    def position(self, now):
        """Playback position, interpolated between mpv's updates."""
        if self.pos is None:
            return None
        if self.paused:
            return self.pos
        return self.pos + min(now - self.pos_t, 0.25)

    def run(self):
        buf = b""
        while True:
            try:
                data = self.sock.recv(65536)
            except OSError:
                return
            if not data:
                return
            buf += data
            *lines, buf = buf.split(b"\n")
            for line in lines:
                try:
                    msg = json.loads(line)
                except ValueError:
                    continue
                if msg.get("event") != "property-change":
                    continue
                name, val = msg.get("name"), msg.get("data")
                if name == "time-pos":
                    self.pos = val
                    self.pos_t = time.monotonic()
                elif name == "pause":
                    self.paused = bool(val)
                    self.pos_t = time.monotonic()
                elif name == "volume" and val is not None:
                    self.volume = val
                elif name == "mute":
                    self.muted = bool(val)


# ── Spectrum ───────────────────────────────────────────────────────────────
class Analyzer:
    def __init__(self, n_bars):
        self.window = np.hanning(FFT_SIZE).astype(np.float32)
        freqs = np.fft.rfftfreq(FFT_SIZE, 1.0 / RATE)
        idx = np.searchsorted(freqs, np.geomspace(F_LO, F_HI, n_bars + 1))
        self.lo = idx[:-1].copy()
        self.hi = np.maximum(idx[1:], self.lo + 1)
        self.levels = np.zeros(n_bars)
        self.peak_db = -30.0

    def update(self, samples, dt):
        if samples is None:
            target = np.zeros_like(self.levels)
        else:
            spec = np.abs(np.fft.rfft(samples * self.window)) / (FFT_SIZE / 4)
            cum = np.concatenate(([0.0], np.cumsum(spec * spec)))
            # Summed power per log-spaced band: music's ~pink spectrum comes out flat.
            db = 10.0 * np.log10(cum[self.hi] - cum[self.lo] + 1e-12)
            loud = float(db.max())
            self.peak_db = max(loud, self.peak_db - PEAK_DECAY_DB_PER_S * dt)
            ceil = max(self.peak_db, -45.0)
            target = np.clip((db - (ceil - RANGE_DB)) / RANGE_DB, 0.0, 1.0)
        up = target > self.levels
        self.levels = np.where(
            up, self.levels + (target - self.levels) * 0.7,
            np.maximum(target, self.levels - FALL_PER_S * dt))
        return self.levels


# ── Drawing ────────────────────────────────────────────────────────────────
class Layout:
    def __init__(self, fd=None, size=None):
        if size is None:
            size = struct.unpack("HHHH", fcntl.ioctl(fd, termios.TIOCGWINSZ, b"\0" * 8))
        rows, cols, xpix, ypix = size
        if not xpix or not ypix:
            xpix, ypix = cols * 8, rows * 16
        cw, ch = max(1, xpix // cols), max(1, ypix // rows)
        self.rows, self.cols = rows, cols
        self.w = cols * cw                    # full terminal width
        self.h = max(ch, (rows - 1) * ch)     # everything above the status line
        n = int(round(self.w / (cw * BAR_CELLS)))
        self.n = max(MIN_BARS, min(MAX_BARS, n))
        period = self.w / self.n
        gap = max(2, round(period * GAP_FRACTION))
        self.border = max(2, round(period * 0.06))
        self.bars = [(round(i * period + gap / 2), round((i + 1) * period - gap / 2))
                     for i in range(self.n)]
        self.min_h = 2 * self.border + 2
        self.buf = np.zeros((self.h, self.w, 4), np.uint8)

    def heights(self, levels, active):
        if not active:
            return (0,) * self.n
        return tuple(max(self.min_h, int(lv * self.h)) for lv in levels)

    def render(self, heights):
        # Gaps are never written, so only each bar's column needs clearing.
        buf, h, b = self.buf, self.h, self.border
        for (x0, x1), bh in zip(self.bars, heights):
            top = h - bh
            buf[:top, x0:x1] = 0
            if bh <= 0:
                continue
            buf[top:h, x0:x1] = (*BORDER, 255)
            if bh > 2 * b and x1 - x0 > 2 * b:
                buf[top + b:h - b, x0 + b:x1 - b] = (*FILL, 255)
        return buf


def write_all(fd, data):
    view = memoryview(data).cast("B")
    while view:
        view = view[os.write(fd, view):]


def apc(keys, payload=b""):
    return b"\033_G" + keys.encode() + b";" + payload + b"\033\\"


def send_frame(out, buf, w, h):
    fd, path = tempfile.mkstemp(prefix=FRAME_PREFIX, suffix=".rgba", dir=SHM)
    try:
        write_all(fd, buf)
    finally:
        os.close(fd)
    keys = f"a=T,f=32,t=t,s={w},v={h},i={IMAGE_ID},p=1,q=2,C=1"
    write_all(out, b"\033[1;1H" + apc(keys, base64.standard_b64encode(path.encode())))


def sweep_frames(max_age):
    """Delete frame files the terminal has not consumed (kitty deletes the rest)."""
    now = time.time()
    for p in glob.glob(os.path.join(SHM, FRAME_PREFIX + "*")):
        try:
            if now - os.path.getmtime(p) >= max_age:
                os.unlink(p)
        except OSError:
            pass


def graphics_supported(fd_in, fd_out):
    """Probe for Kitty graphics *with* temp-file transmission, which we rely on."""
    fd, path = tempfile.mkstemp(prefix=FRAME_PREFIX, suffix=".rgb", dir=SHM)
    os.write(fd, b"\0\0\0")
    os.close(fd)
    query = apc("i=31,s=1,v=1,a=q,t=t,f=24", base64.standard_b64encode(path.encode()))
    write_all(fd_out, query + b"\033[c")  # DA1 reply marks the end of the answer
    buf, deadline = b"", time.monotonic() + 1.5
    while (left := deadline - time.monotonic()) > 0:
        if not select.select([fd_in], [], [], left)[0]:
            break
        buf += os.read(fd_in, 1024)
        if re.search(rb"\033\[\?[\d;]*c", buf):
            break
    try:
        os.unlink(path)
    except OSError:
        pass
    return b"\033_Gi=31;OK" in buf


# ── Status line ────────────────────────────────────────────────────────────
def cell_width(s):
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else
               0 if unicodedata.combining(c) else 1 for c in s)


def clip(s, width):
    out, used = [], 0
    for c in s:
        cw = cell_width(c)
        if used + cw > width:
            return "".join(out[:-1]) + "…" if out else ""
        out.append(c)
        used += cw
    return "".join(out)


def fmt_time(t):
    if t is None:
        return "--:--"
    t = int(t)
    return f"{t // 3600}:{t // 60 % 60:02}:{t % 60:02}" if t >= 3600 else f"{t // 60}:{t % 60:02}"


def status_line(cols, title, ipc, duration, loading):
    lav = "\033[38;2;%d;%d;%dm" % FILL
    yel = "\033[38;2;%d;%d;%dm" % BORDER
    dim, rst = "\033[2m", "\033[0m"
    icon = "…" if loading else ("⏸" if ipc.paused else "▶")
    vol = "muted" if ipc.muted else f"vol {int(round(ipc.volume))}%"
    info = f"{fmt_time(ipc.pos)} / {fmt_time(duration)}  {vol}  "
    hints = "space pause · ↑↓ vol · m mute · q quit "
    if cell_width(info) + cell_width(hints) + 12 > cols:
        hints = ""
    right_w = cell_width(info) + cell_width(hints)
    left = clip(title, max(0, cols - right_w - 4))
    pad = max(1, cols - 3 - cell_width(left) - right_w)
    return f" {yel}{icon}{rst} {lav}{left}{rst}{' ' * pad}{info}{dim}{hints}{rst}"


def parse_keys(data):
    keys, i = [], 0
    while i < len(data):
        if data.startswith(b"\033_", i):        # stray graphics-protocol reply
            j = data.find(b"\033\\", i)
            i = len(data) if j < 0 else j + 2
        elif data.startswith((b"\033[", b"\033O"), i):
            j = i + 2
            while j < len(data) and not 0x40 <= data[j] <= 0x7E:
                j += 1
            keys.append(data[i:j + 1])
            i = j + 1
        else:
            keys.append(data[i:i + 1])
            i += 1
    return keys


# ── Main ───────────────────────────────────────────────────────────────────
def run(arg):
    fd_in, fd_out = sys.stdin.fileno(), sys.stdout.fileno()
    if not (os.isatty(fd_in) and os.isatty(fd_out)):
        raise Fatal("must be run in a terminal")

    src, title, duration, headers = resolve(arg)

    saved_tty = termios.tcgetattr(fd_in)
    procs, sock_dir = [], tempfile.mkdtemp(prefix="mpv-play-")
    ff_err = tempfile.TemporaryFile()
    entered = False
    try:
        tty.setcbreak(fd_in)
        if not graphics_supported(fd_in, fd_out):
            raise Fatal("this terminal does not support the Kitty graphics protocol "
                        "(use kitty, ghostty or wezterm)")

        ff_cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-nostdin"]
        if re.match(r"https?://", src):
            ff_cmd += ["-reconnect", "1", "-reconnect_streamed", "1",
                       "-reconnect_delay_max", "5"]
            if headers:
                ff_cmd += ["-headers", "".join(f"{k}: {v}\r\n" for k, v in headers.items())]
        ff_cmd += ["-i", src, "-vn", "-ac", str(CHANNELS), "-ar", str(RATE),
                   "-f", "s16le", "-"]
        ff = subprocess.Popen(ff_cmd, stdin=subprocess.DEVNULL,
                              stdout=subprocess.PIPE, stderr=ff_err)
        procs.append(ff)

        sock = os.path.join(sock_dir, "ipc")
        mpv = subprocess.Popen(
            [MPV, "--no-video", "--no-terminal", "--idle=no",
             "--input-default-bindings=no", f"--input-ipc-server={sock}",
             "--demuxer=rawaudio", "--demuxer-rawaudio-format=s16le",
             f"--demuxer-rawaudio-rate={RATE}", f"--demuxer-rawaudio-channels={CHANNELS}",
             "--cache=no", f"--force-media-title={title}", "-"],
            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, bufsize=0)
        procs.append(mpv)

        ipc = MpvIPC(sock, mpv)
        ipc.start()
        ring, state = Ring(RING_SECONDS), {"got_audio": False}
        threading.Thread(target=feed, args=(ff, mpv, ring, state), daemon=True).start()

        resized = [False]
        signal.signal(signal.SIGWINCH, lambda *_: resized.__setitem__(0, True))

        write_all(fd_out, b"\033[?1049h\033[?25l\033[2J")
        entered = True
        layout = Layout(fd_out)
        analyzer = Analyzer(layout.n)
        last_heights = last_status = None
        frame_dt = 1.0 / FPS
        next_t = last_t = time.monotonic()
        last_sweep = next_t

        while mpv.poll() is None:
            wait = max(0.0, next_t - time.monotonic())
            if select.select([fd_in], [], [], wait)[0]:
                for key in parse_keys(os.read(fd_in, 256)):
                    if key in (b"q", b"Q"):
                        return 0
                    if key in (b" ", b"p"):
                        ipc.command("cycle", "pause")
                    elif key in (b"\033[A", b"\033OA", b"0", b"+", b"="):
                        ipc.command("add", "volume", 5)
                    elif key in (b"\033[B", b"\033OB", b"9", b"-"):
                        ipc.command("add", "volume", -5)
                    elif key == b"m":
                        ipc.command("cycle", "mute")
            now = time.monotonic()
            if now < next_t:
                continue
            next_t = max(next_t + frame_dt, now)
            dt, last_t = now - last_t, now

            if resized[0]:
                resized[0] = False
                layout = Layout(fd_out)
                analyzer = Analyzer(layout.n)
                last_heights = last_status = None
                write_all(fd_out, apc(f"a=d,d=I,i={IMAGE_ID},q=2") + b"\033[2J")

            pos = ipc.position(now)
            samples = None if pos is None else ring.read(int(pos * RATE), FFT_SIZE)
            levels = analyzer.update(samples, dt)
            heights = layout.heights(levels, pos is not None and state["got_audio"])
            if heights != last_heights:
                send_frame(fd_out, layout.render(heights), layout.w, layout.h)
                last_heights = heights

            status = status_line(layout.cols, title, ipc, duration,
                                 loading=not state["got_audio"])
            if status != last_status:
                write_all(fd_out, f"\033[{layout.rows};1H\033[2K{status}".encode())
                last_status = status

            if now - last_sweep > 2.0:
                sweep_frames(max_age=2.0)
                last_sweep = now

        if ff.poll() not in (None, 0) and not state["got_audio"]:
            ff_err.seek(0)
            err = ff_err.read().decode(errors="replace").strip().splitlines()
            raise Fatal("ffmpeg failed" + (f": {err[-1]}" if err else ""))
        return 0
    finally:
        for p in reversed(procs):
            if p.poll() is None:
                p.terminate()
        for p in procs:
            try:
                p.wait(timeout=2)
            except subprocess.TimeoutExpired:
                p.kill()
        if entered:
            write_all(fd_out, apc(f"a=d,d=I,i={IMAGE_ID},q=2")
                      + b"\033[?25h\033[0m\033[?1049l")
        termios.tcsetattr(fd_in, termios.TCSADRAIN, saved_tty)
        shutil.rmtree(sock_dir, ignore_errors=True)
        sweep_frames(max_age=0)


def main():
    if len(sys.argv) != 2 or sys.argv[1] in ("-h", "--help"):
        sys.stderr.write("Usage: mpv-play <URL | file>\n"
                         "Keys: space/p pause · ↑/↓ or 0/9 volume · m mute · q quit\n")
        return 0 if len(sys.argv) == 2 else 1
    for sig in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, lambda *_: sys.exit(130))
    try:
        return run(sys.argv[1])
    except KeyboardInterrupt:
        return 130
    except Fatal as e:
        sys.stderr.write(f"mpv-play: {e}\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())
