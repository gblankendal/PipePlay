# yt — a keyboard-driven YouTube CLI player

A single bash script that turns `mpv` + `yt-dlp` + `fzf` into a fast,
no-browser way to search, watch, and organize YouTube videos and
playlists from the terminal. No ads, no recommendation rabbit-hole,
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
the machine out the window.

Out of frustration I started looking into lighter alternatives, which
is what pushed me into installing Linux in the first place — I'm on
**MX Linux (Xfce edition)** now, running Debian 13 (Trixie) under the
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

## How it actually works

Four tools, each doing one job:

| Tool     | Job                                                                 |
|----------|----------------------------------------------------------------------|
| `yt-dlp` | Talks to YouTube. Resolves search terms, video IDs, and playlist URLs into real stream URLs and metadata (title, channel, views, duration) — without ever loading a browser page. |
| `mpv`    | Actually plays the video/audio stream that `yt-dlp` hands it. This is the only part doing real decoding/rendering work. |
| `fzf`    | Powers the interactive fuzzy-search pickers (`-l` / `-L` / `--playlists`) — type a few letters, arrow down, hit enter. |
| `jq`     | Parses the JSON that `yt-dlp` returns (titles, view counts, IDs, etc.) so the script can format and display it. |

The script itself is the glue: it parses your flags, decides which of
those four tools to call and in what order, formats the terminal
output, and manages a small local library of saved playlists so you
don't have to re-paste URLs every time.

### Where your data lives

Everything is stored under the XDG data directory (respects
`$XDG_DATA_HOME` if set, otherwise defaults to `~/.local/share`):

```
~/.local/share/yt/
├── playlists/        Saved playlists, one JSON file per playlist
├── watch_later/       mpv's own resume data (exact video + timestamp)
└── cache/              Scratch space, wiped automatically every run
```

Nothing is ever sent anywhere except direct requests to YouTube itself
(via `yt-dlp`) to fetch metadata and stream URLs.

### Automatic cleanup

Storage is precious on old/small drives, so the script cleans up after
itself **every single time it exits** — normal exit, error, or Ctrl-C:

- `yt-dlp`'s own on-disk cache is wiped (fully disposable, it
  regenerates itself as needed).
- Any leftover temp files from an interrupted `--sync` are removed.
- The script's own scratch folder is cleared.
- Resume ("watch later") entries untouched for 45+ days are pruned,
  since they're almost certainly abandoned.

Your saved playlists are **never** touched by this automatic pass, and
recent resume points are always kept. If you want a more aggressive,
on-demand clean (e.g. you're about to run out of disk right now), use
`yt --clean` — see the command reference below.

---

## Installation (MX Linux / Debian / Ubuntu)

### 1. Install the dependencies

```bash
sudo apt update
sudo apt install mpv jq fzf
```

`yt-dlp` moves fast, so it's best installed via `pip` rather than the
(often outdated) apt package, so you can update it easily whenever
YouTube changes something:

```bash
sudo apt install pipx
pipx install yt-dlp
pipx ensurepath
```

If `pipx` isn't available on your system, `pip install --user yt-dlp`
works too — just make sure `~/.local/bin` is on your `$PATH`.

Verify everything is installed:

```bash
mpv --version
yt-dlp --version
jq --version
fzf --version
```

### 2. Get the script onto your machine

Save the script as `yt` (no extension), then make it executable and
put it somewhere on your `$PATH`:

```bash
mkdir -p ~/bin
mv yt ~/bin/yt
chmod +x ~/bin/yt
```

Make sure `~/bin` is on your `$PATH`. Add this to `~/.bashrc` (or
`~/.profile`) if it isn't already:

```bash
export PATH="$HOME/bin:$PATH"
```

Then reload your shell:

```bash
source ~/.bashrc
```

### 3. Test it

```bash
yt never gonna give you up
```

If a video starts playing in `mpv`, you're done.

---

## Full command reference

### Just play something

```bash
yt VIDEO_ID                 # play a specific YouTube video ID
yt "https://youtu.be/..."   # play a full URL (quote it if it has &)
yt search terms here        # search YouTube, play the first result
```

### Interactive search (recommended for anything ambiguous)

```bash
yt -l search terms          # fzf picker: title / channel / views / length
yt -L search terms          # same picker, but shows full details before playing
```

Type to filter, arrow keys to move, Enter to play, Esc to cancel.

### Played on a loop

```bash
yt -loop lofi hip hop radio       # loops the resolved video forever
yt --study my_lecture_playlist -loop   # loops the whole playlist
```

`-loop` can go anywhere in the command — before or after your search
terms, it doesn't matter:

```bash
yt lofi hip hop radio -loop     # also works
```

### Playback quality / audio-only

```bash
yt -480 some video      # cap at 480p
yt -720 some video      # cap at 720p (default)
yt -1080 some video     # cap at 1080p
yt -a some podcast       # audio only, no video decoding at all
```

### Playlists you haven't saved yet

```bash
yt "https://youtube.com/playlist?list=PL..."   # browse/play, not saved
yt PL4cUxeGkcC9gm4_-5UsNThsvpZ1qeh6qL           # bare playlist ID also works
```

Opens an fzf menu: **Play All**, **Shuffle All**, or jump straight to
any specific track in the list.

### Your saved library

```bash
yt --save-playlist "https://youtube.com/playlist?list=PL..."
```

Fetches the playlist and stores it locally under
`~/.local/share/yt/playlists/`, keyed by a slugified version of its
title (e.g. "Physics Wallah - Electrostatics!" →
`physics_wallah_electrostatics.json`).

```bash
yt --playlists          # or: yt --library
```

Browse everything you've saved, in the same Play All / Shuffle All /
jump-to-track picker as above.

```bash
yt --study                    # browse saved playlists, resume instantly on pick
yt --study physics_wallah     # resume a specific saved playlist by name
```

`--study` is the "pick up exactly where I left off" command — it uses
mpv's own resume data (matched by URL) to jump back to the precise
video and timestamp you stopped at.

```bash
yt --shuffle physics_wallah     # play a saved playlist in random order
```

```bash
yt --sync                       # refetch ALL saved playlists, report new videos
yt --sync physics_wallah        # refetch just one, report new videos
```

Playlist owners add new videos over time — `--sync` refreshes your
local copy and tells you how many new videos showed up, without
losing your existing data.

```bash
yt --queue physics_wallah,chemistry_basics,exam_revision
```

Plays several saved playlists back to back in a single session (comma
separated, no spaces needed around the commas). Combine with `-loop`
to loop the entire queue forever.

### Maintenance

```bash
yt --clean
```

An on-demand deep clean for when you're tight on disk right now. This
wipes yt-dlp's cache, the script's scratch space, **and every** resume
point in `watch_later` (not just the stale ones the automatic cleanup
prunes) — so you'll lose your place in anything you were mid-way
through. Your saved playlists themselves are never deleted by this.

---

## Command cheat sheet

| Command | What it does |
|---|---|
| `yt VIDEO_ID` / `yt URL` | Play directly |
| `yt search terms` | Search, play first result |
| `yt -l search terms` | Interactive search picker |
| `yt -L search terms` | Interactive search picker + full details first |
| `yt -loop ...` | Loop the video/playlist forever (works anywhere in the command) |
| `yt -480` / `-720` / `-1080` | Cap playback resolution |
| `yt -a` / `-audio` | Audio only |
| `yt PLAYLIST_URL_OR_ID` | Browse/play a playlist without saving it |
| `yt --save-playlist URL` | Save a playlist to your local library |
| `yt --playlists` / `--library` | Browse your saved playlists |
| `yt --study [NAME]` | Resume a saved playlist where you left off |
| `yt --sync [NAME]` | Refetch playlist(s), report new videos |
| `yt --shuffle NAME` | Play a saved playlist shuffled |
| `yt --queue A,B,C` | Play several saved playlists back to back |
| `yt --clean` | Deep-clean cache + all resume points now |

---

## Tuning for low-end hardware

The defaults in this script are tuned for exactly the kind of machine
that inspired it — an old dual-core CPU with no real hardware video
decoding and a small amount of RAM. If you're running on similar
hardware, these should just work out of the box. If you're on
something newer, the relevant variables are all clearly labeled near
the top of the script:

- `QUALITY` — default playback resolution cap
- `HWDEC` — hardware decode mode (off by default on old Intel chips
  with no reliable H.264 hw decode path)
- `VO_CHAIN` — mpv's video output driver priority list
- `CPU_THREADS` — decoder thread count, match to your actual CPU
- `DEMUX_MAX` / `DEMUX_BACK` — how much mpv buffers in RAM
- `CACHE_MAX_AGE_DAYS` — how long unused resume points are kept before
  automatic pruning

If mpv prints warnings on startup about Vulkan, old GLSL versions, or
"Late SEI is not implemented" on stock configs — these are all
harmless fallback/decoder notices on older graphics hardware, not
actual errors, and this script already quiets the noisy ones by
default.

---

## Requirements

- `bash`
- [`mpv`](https://mpv.io/)
- [`yt-dlp`](https://github.com/yt-dlp/yt-dlp)
- [`jq`](https://stedolan.github.io/jq/)
- [`fzf`](https://github.com/junegunn/fzf)

All available via `apt` on Debian/Ubuntu/MX Linux (yt-dlp best via
`pipx`/`pip` as noted above for faster updates).

---

## Contributing

Found a bug, or hit a warning this README doesn't explain? Issues and
pull requests are welcome — this script was built to fix a real
problem on real underpowered hardware, so reports from other low-end
setups are especially useful.

---

## Support this project

This script exists because I couldn't afford a computer that could
handle YouTube normally. If it's useful to you and you're able to
chip in toward a better laptop for me, it would mean a lot:

[**DONATOIN PAGE**]([PAYPAL LINK](https://www.paypal.com/ncp/payment/Y2KWVATVRLJSQ))

No obligation at all — starring the repo or sharing it with someone
else stuck on old hardware helps just as much.
