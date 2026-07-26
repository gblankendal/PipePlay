#!/usr/bin/env bash
#
# player.sh - Video and playlist playback functions
#
# Handles mpv invocation, format selection, and playback control.
#

# Build the base mpv arguments that are used for all playback
# Must be called after config is initialized
# shellcheck disable=SC2034  # mpv_args_ref is used via nameref and modified by this function
build_mpv_args() {
    local quality="${1:-$DEFAULT_QUALITY}"
    local audio_only="${2:-0}"
    local -n mpv_args_ref="$3"  # Pass array by reference
    
    # Get the appropriate format string
    local format_str
    format_str=$(get_format_string "$quality" "$audio_only") || return 1

    # Build the argument array
    # shellcheck disable=SC2054  # False positive: array already uses spaces, not commas
    mpv_args_ref=(
        --hwdec="$HWDEC_MODE"
        --vo="$VO_CHAIN"
        --gpu-api=opengl           # Skip Vulkan probe, go straight to GL
        --msg-level=ffmpeg=error,vo=error   # Hide harmless fallback messages
        --vd-lavc-threads="$DECODE_THREADS"
        --demuxer-max-bytes="$DEMUX_MAX_BYTES"
        --demuxer-max-back-bytes="$DEMUX_BACK_BYTES"
        --ytdl-format="$format_str"
        --save-position-on-quit
        --watch-later-directory="$PipePlay_WATCH_LATER_DIR"
    )
}

# Play a single video from a URL
# Usage: play_video "https://youtu.be/dQw4w9WgXcQ" [quality] [audio_only] [loop]
play_video() {
    local url="$1"
    local quality="${2:-$DEFAULT_QUALITY}"
    local audio_only="${3:-0}"
    local loop_mode="${4:-0}"

    [[ -z "$url" ]] && die "play_video: URL is required"

    local mpv_args=()
    build_mpv_args "$quality" "$audio_only" mpv_args || return 1
    
    # Add loop flag if requested
    [[ $loop_mode -eq 1 ]] && mpv_args+=(--loop-file=inf)
    
    log_info "Starting playback: $url"
    mpv "${mpv_args[@]}" "$url"
}

# Play a playlist from a URL
# Usage: play_playlist "https://www.youtube.com/playlist?list=..." [start_idx] [shuffle] [quality] [audio_only] [loop]
play_playlist() {
    local url="$1"
    local start_index="${2:-}"
    local shuffle="${3:-0}"
    local quality="${4:-$DEFAULT_QUALITY}"
    local audio_only="${5:-0}"
    local loop_mode="${6:-0}"

    [[ -z "$url" ]] && die "play_playlist: URL is required"

    local mpv_args=()
    build_mpv_args "$quality" "$audio_only" mpv_args || return 1
    
    # Set starting position in playlist if specified
    if [[ -n "$start_index" && "$start_index" != "0" ]]; then
        mpv_args+=(--playlist-start=$((start_index - 1)))
    fi
    
    # Add shuffle flag if requested
    [[ $shuffle -eq 1 ]] && mpv_args+=(--shuffle)
    
    # Add loop flag if requested
    [[ $loop_mode -eq 1 ]] && mpv_args+=(--loop-playlist=inf)
    
    log_info "Starting playlist playback (shuffle=$shuffle): $url"
    mpv "${mpv_args[@]}" "$url"
}

# Queue multiple playlists to play back-to-back
# Usage: play_queue [quality] [audio_only] [loop] url1 url2 url3 ...
play_queue() {
    local quality="${1:-$DEFAULT_QUALITY}"
    local audio_only="${2:-0}"
    local loop_mode="${3:-0}"
    shift 3
    
    local -a urls=("$@")
    
    if [[ ${#urls[@]} -eq 0 ]]; then
        die "play_queue: At least one URL is required"
    fi

    local mpv_args=()
    build_mpv_args "$quality" "$audio_only" mpv_args || return 1
    
    # Add loop flag if requested
    [[ $loop_mode -eq 1 ]] && mpv_args+=(--loop-playlist=inf)
    
    log_info "Starting queued playback (${#urls[@]} playlists)"
    mpv "${mpv_args[@]}" "${urls[@]}"
}

# Get the next/previous video in a playlist
# This is called by the playlist picker after user selects an action
# Returns: The URL, start index, and shuffle mode as separate lines
get_playlist_action_from_picker() {
    local selection="$1"
    local url="$2"
    
    # selection format: "CONTROL\tINDEX\tDISPLAY"
    local control idx_sel
    IFS=$'\t' read -r control idx_sel _ <<< "$selection"
    
    case "$control" in
        ALL)     
            echo "$url"
            echo ""
            echo "0"
            ;;
        SHUFFLE)
            echo "$url"
            echo ""
            echo "1"
            ;;
        VIDEO)
            echo "$url"
            echo "$idx_sel"
            echo "0"
            ;;
        *)
            return 1
            ;;
    esac
}
