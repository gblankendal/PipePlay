# PipePlay – Terminal YouTube Experience

A single bash script that turns `mpv` + `yt-dlp` + `fzf` into a fast,
no-browser way to search, watch, and organize YouTube videos and
playlists from the terminal. No recommendation rabbit-hole,
no bloated web player — just you, a search term, and a video that
starts playing in under a second.

---

## Why this exists

I built this because my PC genuinely could not handle YouTube.

I'm running this on an old Pentium Dual-Core E5700 with 4GB of RAM and
Intel G41 integrated graphics — hardware from around 2010. Opening
youtube.com in a browser on Windows was miserable: the page itself
would chug, autoplay previews would eat what little CPU I had, and
actual video playback dropped frames constantly. My parents couldn't
afford to get me a new laptop, and honestly, I understood — but I
still wanted to watch and study from YouTube without wanting to throw
my machine out the window.

Out of frustration I started looking into lighter alternatives,
which is what pushed me into installing Linux in the first place — I'm
on **MX Linux (Xfce edition)** now, running Debian 13 (Trixie) under the
hood. That switch alone made the machine feel usable again. But the
browser was still the bottleneck for YouTube specifically, so I built
this script around `mpv` (a lightweight native video player) and
`yt-dlp` (which extracts direct video streams without ever loading a
full webpage). No browser, no JavaScript, no ads — just the video
stream, decoded as efficiently as this old hardware allows.

What started as "just play a video ID" grew into full playlist
support, a saved library, resume/sync, and fzf-powered search — because
once YouTube was usable again, I wanted to actually use it properly
for studying, not just survive it.

If this script saves your old machine too, and you'd like to help me
put money toward a decent laptop one day, there's a donation link at
the bottom. No pressure at all — sharing this is enough.

---

**Disclaimer**: PipePlay is an independent open-source project and is not affiliated with or endorsed by YouTube or Google. Users are responsible for complying with the terms of service and applicable copyright laws for the content they access.

---

## How it works

Four tools, each doing one job:

| Tool     | Job |
|----------|-----|
| `yt-dlp` | Talks to YouTube. Resolves search terms, video IDs, and playlist URLs into real stream URLs and metadata (title, channel, views, duration) — without ever loading a browser page. |
| `mpv`    | Actually plays the video/audio stream that `yt-dlp` hands it. This is the only part doing real decoding and rendering work. |
| `fzf`    | Powers the interactive selection UIs for search results and playlist browsing. |
| `jq`     | Parses the JSON that `yt-dlp` returns so the script can format output and build playlists. |

The script is the glue: it parses your flags, decides which commands to
run, formats terminal output, and manages a small local playlist library.

### Where your data lives

Everything is stored under the XDG data directory (respects
`$XDG_DATA_HOME`, otherwise defaults to `~/.local/share`):

```
~/.local/share/yt/
├── playlists/        Saved playlists, one JSON file per playlist
├── watch_later/      mpv resume data (video + timestamp)
└── cache/            Scratch space, wiped automatically every run
```

Nothing is ever sent anywhere except direct requests to YouTube itself
(via `yt-dlp`) to fetch metadata and stream URLs.

### Automatic cleanup

Storage is precious on old or small drives, so the script cleans up after
itself every time it exits — normal exit, error, or Ctrl-C:

- `yt-dlp` cache is cleared.
- Interrupted temporary files are removed.
- The script scratch cache is wiped.
- Old mpv resume points are pruned after 45 days.

Saved playlists are never deleted automatically. If you want a stronger,
on-demand clean, use `pipeplay --clean`.

---

## Install

### Required tools

Install the basics first:

```bash
sudo apt update
sudo apt install git mpv jq fzf
```

For `yt-dlp`, install via `pipx` if possible:

```bash
sudo apt install pipx
pipx install yt-dlp
pipx ensurepath
```

If `pipx` is not available, use:

```bash
pip install --user yt-dlp
```

### Install PipePlay with git

Clone the repository into a folder under your home directory. This keeps the
project in one place and makes it easy to update later:

```bash
mkdir -p "$HOME/src"
git clone https://github.com/nvsupr/PipePlay.git "$HOME/src/PipePlay"
```

That command creates a full local copy of the repo at:

```bash
~/src/PipePlay
```

Inside that folder you'll find:

- `~/src/PipePlay/pipeplay` — the main script
- `~/src/PipePlay/lib/` — the supporting shell modules

Make the launcher executable and add command shims in `~/bin` so you can run
`pipeplay`, `pplay`, and `ppy` from anywhere:

```bash
mkdir -p "$HOME/bin"
chmod +x "$HOME/src/PipePlay/pipeplay"
ln -sf "$HOME/src/PipePlay/pipeplay" "$HOME/bin/pipeplay"
ln -sf "$HOME/src/PipePlay/pipeplay" "$HOME/bin/pplay"
ln -sf "$HOME/src/PipePlay/pipeplay" "$HOME/bin/ppy"
```

Make sure `~/bin` is on your PATH. If not, add this to `~/.bashrc` or
`~/.zshrc`:

```bash
export PATH="$HOME/bin:$PATH"
```

Then reload your shell:

```bash
source ~/.bashrc
```

If you ever want to update PipePlay later, run:

```bash
cd "$HOME/src/PipePlay"
git pull
```

### Verify installation

```bash
pipeplay --help
mpv --version
yt-dlp --version
jq --version
fzf --version
```

---

## Usage

```bash
ppy never gonna give you up
ppy https://youtu.be/dQw4w9WgXcQ
ppy -l never gonna give you up
ppy -L never gonna give you up
ppy --search
ppy --block-60fps never gonna give you up
ppy --max-fps 30 never gonna give you up
ppy --save-playlist https://www.youtube.com/playlist?list=...
ppy --playlists
ppy --study MyPlaylist
ppy --sync MyPlaylist
ppy --shuffle MyPlaylist
ppy --queue PlaylistA,PlaylistB
ppy --clean
ppy --help
```

`pplay` and `pipeplay` are supported aliases for the same CLI and behave identically.
Running `pipeplay` with no query starts a blank search prompt, which is handy if you
launch it from a desktop entry or just want to type a search term interactively.

## Config

Create `~/.config/yt/config.sh` to override defaults and preserve your
settings across updates:

```bash
DEFAULT_QUALITY=480
HWDEC_MODE="auto"
MAX_FPS=30
```

## Data locations

- `~/.local/share/yt/playlists`
- `~/.local/share/yt/watch_later`
- `~/.local/share/yt/cache`

## Help

Run `pipeplay --help` or `pipeplay -h` for usage information.

---

## ❤️ Support This Project

I built this project on a 15-year-old Pentium PC because I couldn't afford a machine that could handle YouTube comfortably.

If this utility has helped you breathe new life into an old computer, and you'd like to support future development, consider making a small donation. It helps me maintain the project, add new features, and eventually upgrade my development hardware.

<p align="center">
  <a href="https://www.paypal.com/ncp/payment/Y2KWVATVRLJSQ">
    <img src="https://img.shields.io/badge/❤️_Donate_via_PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white" alt="Donate via PayPal">
  </a>
</p>

---

## 🌐 Connect

<p align="center">

<a href="https://www.reddit.com/user/kiarob/">
  <img src="https://img.shields.io/badge/Reddit-u%2Fkiarob-FF4500?style=for-the-badge&logo=reddit&logoColor=white" alt="Reddit">
</a>

<a href="https://www.youtube.com/@TylerOrvex">
  <img src="https://img.shields.io/badge/YouTube-@TylerOrvex-FF0000?style=for-the-badge&logo=youtube&logoColor=white" alt="YouTube">
</a>

<a href="https://x.com/novarchx">
  <img src="https://img.shields.io/badge/X-@novarchx-000000?style=for-the-badge&logo=x&logoColor=white" alt="X">
</a>

<a href="https://telegram.dog/loganzen">
  <img src="https://img.shields.io/badge/Telegram-@loganzen-26A5E4?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram">
</a>

<a href="https://www.web.us.kg/">
  <img src="https://img.shields.io/badge/Website-web.us.kg-0A66C2?style=for-the-badge&logo=googlechrome&logoColor=white" alt="Website">
</a>

</p>

If PipePlay helped you, a ⭐ on the repo, bug reports, feature suggestions, or simply sharing it with someone else using older hardware all mean a lot. ❤️
