#!/usr/bin/env bash
#
# config.sh - Configuration and constants for PipePlay
#
# Centralized place for all tunable parameters and system-level settings.
# Hardware tuning, paths, and performance parameters are defined here.
#

# shellcheck disable=SC2034  # These variables are used externally (exported or used by sourced modules)

# ---------------------------------------------------------------------------
# HARDWARE & PERFORMANCE TUNING
# ---------------------------------------------------------------------------
# These defaults are optimized for: Pentium Dual-Core E5700 (2C/2T @ 3GHz),
# 4GB RAM, Intel G41 integrated graphics (no usable H.264 hw decode),
# and a ~1366x768 display.
#
# Adjust these values when running on different hardware:

# Default video quality (720 matches ~1366x768 display; 1080 burns CPU)
readonly DEFAULT_QUALITY="${DEFAULT_QUALITY:-720}"

# Hardware acceleration: "no" (software only) or "auto" (probe for hw decode)
# G41/Mesa has no reliable H.264 hw decode, so default is "no".
# Change to "auto" on newer hardware.
readonly HWDEC_MODE="${HWDEC_MODE:-no}"

# Video output chain: gpu (via Mesa) with x11 fallback
# xv was tried but performs software path ("X11 can't keep up")
readonly VO_CHAIN="${VO_CHAIN:-gpu,x11}"

# Number of threads for video decoding (matches available cores)
readonly DECODE_THREADS="${DECODE_THREADS:-2}"

# Demuxer cache limits (for 4GB RAM and small SSD)
readonly DEMUX_MAX_BYTES="${DEMUX_MAX_BYTES:-50MiB}"
readonly DEMUX_BACK_BYTES="${DEMUX_BACK_BYTES:-25MiB}"

# Maximum age (in days) before watch_later entries are auto-pruned
readonly CACHE_MAX_AGE_DAYS="${CACHE_MAX_AGE_DAYS:-45}"

# Maximum FPS to allow for video download/selection.
# Set to 0 to allow all framerates.
MAX_FPS="${MAX_FPS:-0}"

# ---------------------------------------------------------------------------
# DATA DIRECTORIES (XDG compliant)
# ---------------------------------------------------------------------------

# Root data directory (respects XDG_DATA_HOME if set)
PipePlay_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/yt"

# Subdirectories
readonly PipePlay_PLAYLISTS_DIR="$PipePlay_DATA_DIR/playlists"
readonly PipePlay_CACHE_DIR="$PipePlay_DATA_DIR/cache"
readonly PipePlay_WATCH_LATER_DIR="$PipePlay_DATA_DIR/watch_later"
readonly PipePlay_HISTORY_FILE="$PipePlay_DATA_DIR/history.json"

# ---------------------------------------------------------------------------
# BEHAVIOR & DEFAULTS
# ---------------------------------------------------------------------------

# Default fzf height
readonly FZF_HEIGHT="90%"

# Truncate title/channel to these lengths (in columns)
readonly TITLE_MAX_LENGTH=57
readonly CHANNEL_MAX_LENGTH=20
readonly SHORT_TITLE_LENGTH=50

# Table formatting for playlist picker
readonly PLAYLIST_PICKER_WIDTH_TRACK=3
readonly PLAYLIST_PICKER_WIDTH_TITLE=50
readonly PLAYLIST_PICKER_WIDTH_CHANNEL=18

# Search result limits
readonly SEARCH_RESULTS_LIMIT=10
readonly SEARCH_PLAYLIST_LIMIT=10

# Video quality presets (in resolution order)
if [[ -z "${QUALITY_FORMATS+x}" ]]; then
    declare -A QUALITY_FORMATS=(
        [480]="bestvideo[height<=480][vcodec^=avc1]+bestaudio/best[height<=480]"
        [720]="bestvideo[height<=720][vcodec^=avc1]+bestaudio/best[height<=720]"
        [1080]="bestvideo[height<=1080][vcodec^=avc1]+bestaudio/best[height<=1080]"
        [audio]="bestaudio"
    )
fi

# Default quality format (used when no -quality flag specified)
readonly DEFAULT_VIDEO_FORMAT="${QUALITY_FORMATS[${DEFAULT_QUALITY}]}"
readonly DEFAULT_AUDIO_FORMAT="${QUALITY_FORMATS[audio]}"

# ---------------------------------------------------------------------------
# INITIALIZATION
# ---------------------------------------------------------------------------

# Initialize XDG data directories
init_xdg_dirs() {
    mkdir -p "$PipePlay_PLAYLISTS_DIR" "$PipePlay_CACHE_DIR" "$PipePlay_WATCH_LATER_DIR" || \
        die "Failed to create PipePlay directories"
    
    # Create empty history.json if it doesn't exist
    if [[ ! -f "$PipePlay_HISTORY_FILE" ]]; then
        echo "{}" > "$PipePlay_HISTORY_FILE" || \
            die "Failed to create history file"
    fi
}

# Get video format string based on quality and audio-only flag
get_format_string() {
    local quality="${1:-$DEFAULT_QUALITY}"
    local audio_only="${2:-0}"
    local format

    if [[ $audio_only -eq 1 ]]; then
        format="${QUALITY_FORMATS[audio]}"
    else
        if [[ -v QUALITY_FORMATS[$quality] ]]; then
            format="${QUALITY_FORMATS[$quality]}"
        else
            log_warn "Unknown quality: $quality, using default (${DEFAULT_QUALITY}p)"
            format="$DEFAULT_VIDEO_FORMAT"
        fi
    fi

    if [[ $audio_only -eq 1 || ${MAX_FPS:-0} -le 0 ]]; then
        echo "$format"
        return 0
    fi

    # Add an FPS cap to the video selector only, preserving audio/fallback behavior.
    if [[ "$format" == *+* ]]; then
        local video_part="${format%%+*}"
        local remainder="${format#*+}"
        video_part="${video_part}[fps<=${MAX_FPS}]"
        echo "${video_part}+${remainder}"
    else
        echo "${format}[fps<=${MAX_FPS}]"
    fi
}

# Export runtime config as environment for child processes
export_mpv_config() {
    export PIPEPLAY_HWDEC="$HWDEC_MODE"
    export PIPEPLAY_VO="$VO_CHAIN"
    export PIPEPLAY_THREADS="$DECODE_THREADS"
    export PIPEPLAY_DEMUX_MAX="$DEMUX_MAX_BYTES"
    export PIPEPLAY_DEMUX_BACK="$DEMUX_BACK_BYTES"
    export PIPEPLAY_WATCH_LATER="$PipePlay_WATCH_LATER_DIR"
}
