#!/usr/bin/env bash
#
# ui.sh - User interface and display functions
#
# Handles all interactive prompts, fzf pickers, table formatting, and output.
#

# shellcheck disable=SC2154  # Variables from config.sh are set by sourcing main script
# Global variables referenced but not assigned in this module:
# PipePlay_PLAYLISTS_DIR, FZF_HEIGHT, various formatting constants

# Display usage/help text
show_usage() {
    cat <<'EOF'
Usage:
  pipeplay VIDEO_ID
  pipeplay URL
  pipeplay search terms
  pipeplay                 Start a blank search prompt
  pipeplay -l search terms
  pipeplay -L search terms

Playlists & Library:
  pipeplay PLAYLIST_URL_OR_ID   Browse/play a playlist (not saved)
  pipeplay --save-playlist URL  Save a playlist into your local library
  pipeplay --playlists, --library Browse your saved playlists
  pipeplay --study [NAME]       Resume a saved playlist where you left off
  pipeplay --sync [NAME]        Refetch saved playlist(s), report new videos
  pipeplay --shuffle NAME       Play a saved playlist in shuffled order
  pipeplay --queue NameA,NameB,... Play several saved playlists back to back

Maintenance:
  pipeplay --clean              Deep-clean cache + ALL resume points now
                                 (playlists are auto-cleaned conservatively
                                 after every run; this is the manual, more
                                 aggressive version)

Options (can go anywhere on the command line):
  -480          Max 480p
  -720          Max 720p (default -- matches this display)
  -1080         Max 1080p
  -a, -audio    Audio only
  -l            Interactive search (fzf)
  -L            Interactive search (fzf) with detailed metadata before playback
  --search, -s  Open a blank search prompt before running fzf
  --max-fps N   Restrict playback to videos with <= N FPS
  --block-60fps Same as --max-fps 30
  -h, --help    Show this usage message
  -loop         Loop the current video (or whole playlist) forever
EOF
}

# Build a formatted table header for fzf search results
# Usage: _build_search_header
_build_search_header() {
    printf "%-58s %-21s %8s %8s" "TITLE" "CHANNEL" "VIEWS" "LENGTH"
}

# Build a formatted table row for a search result
# Used internally by fzf_select_id
_format_search_row() {
    local id="$1"
    local title="$2"
    local channel="$3"
    local views="$4"
    local duration="$5"

    local disp_title disp_channel disp_views disp_duration
    disp_title=$(truncate_title "$title" "$TITLE_MAX_LENGTH")
    disp_channel=$(truncate_title "$channel" "$CHANNEL_MAX_LENGTH")
    disp_views=$(format_views "$views")
    disp_duration=$(format_duration "$duration")
    
    # Tab-separated for fzf parsing, with display in the visible column
    printf "%s\t%-58s %-21s %8s %8s" \
        "$id" "$disp_title" "$disp_channel" "$disp_views" "$disp_duration"
}

# Interactive fzf search picker for YouTube videos
# Returns the selected video ID on stdout, or non-zero if user aborts
# Usage: vid_id=$(fzf_select_id "search query") || return 1
fzf_select_id() {
    local query="$*"
    log_info "Searching YouTube for: $query"

    local json
    json=$(yt-dlp --flat-playlist -J "ytsearch${SEARCH_RESULTS_LIMIT}:${query}" 2>/dev/null) || {
        log_error "Failed to search YouTube"
        return 1
    }

    if [[ -z "$json" ]]; then
        log_error "No results found"
        return 1
    fi

    # Extract video data from JSON
    local raw
    raw=$(jq -r '.entries[]? |
        [(.id // ""), (.title // "Unknown title"),
         (.channel // .uploader // "Unknown"),
         (.view_count // 0), (.duration // 0)] | @tsv' <<< "$json") || {
        log_error "Failed to parse search results"
        return 1
    }

    if [[ -z "$raw" ]]; then
        log_error "No results found"
        return 1
    fi

    # Build fzf input with formatted rows
    local fzf_input="" id title channel views duration line
    while IFS=$'\t' read -r id title channel views duration; do
        [[ -z "$id" ]] && continue
        line=$(_format_search_row "$id" "$title" "$channel" "$views" "$duration")
        fzf_input+="$line"$'\n'
    done <<< "$raw"

    # Show fzf picker
    local header selected
    header=$(_build_search_header)
    
    selected=$(printf '%s' "$fzf_input" | fzf \
        --delimiter=$'\t' \
        --with-nth=2 \
        --prompt="pipeplay search> " \
        --height="$FZF_HEIGHT" \
        --border \
        --header="$header" \
        --header-first \
        --no-multi) || return 1

    [[ -z "$selected" ]] && return 1
    
    # Extract and return the video ID (first column)
    cut -f1 <<< "$selected"
}

# Build formatted table header for playlist picker
_build_playlist_header() {
    printf "%-3s %-50s %-18s %8s" "NUM" "TITLE" "CHANNEL" "LENGTH"
}

# Build formatted table row for a playlist entry
_format_playlist_row() {
    local idx="$1"
    local title="$2"
    local channel="$3"
    local duration="$4"

    local disp_title disp_channel disp_duration
    disp_title=$(truncate_title "$title" "$PLAYLIST_PICKER_WIDTH_TITLE")
    disp_channel=$(truncate_title "$channel" "$PLAYLIST_PICKER_WIDTH_CHANNEL")
    disp_duration=$(format_duration "$duration")
    
    printf "%3d. %-50s %-18s %8s" "$idx" "$disp_title" "$disp_channel" "$disp_duration"
}

# Interactive fzf picker for browsing/selecting from a playlist
# Usage: action=$(playlist_picker "Playlist Name" "https://youtube.com/playlist?list=..." "title\tchannel\tduration\n...")
# Returns: control type and data to stdout for caller to parse
# Sets exit code 0 on success, 1 if user cancelled
playlist_picker() {
    local name="$1"
    local url="$2"
    local video_tsv="$3"

    # Build fzf input with special options and video list
    local fzf_input="" idx=0 title channel duration disp_title disp_channel disp_duration line
    fzf_input+="ALL"$'\t'""$'\t'"▶  Play All"$'\n'
    fzf_input+="SHUFFLE"$'\t'""$'\t'"🔀  Shuffle All"$'\n'

    while IFS=$'\t' read -r title channel duration; do
        ((idx++)) || true
        line=$(_format_playlist_row "$idx" "$title" "$channel" "$duration")
        fzf_input+="VIDEO"$'\t'"${idx}"$'\t'"${line}"$'\n'
    done <<< "$video_tsv"

    # Show fzf picker
    local header selected
    header=$(_build_playlist_header)
    
    selected=$(printf '%s' "$fzf_input" | fzf \
        --delimiter=$'\t' \
        --with-nth=3 \
        --prompt="${name}> " \
        --height="$FZF_HEIGHT" \
        --border \
        --header="Playlist: ${name}  (Enter: play all / shuffle all / jump to a track)") || return 1

    [[ -z "$selected" ]] && return 1

    # Parse the selected row and return action details
    local control idx_sel
    IFS=$'\t' read -r control idx_sel _ <<< "$selected"

    case "$control" in
        ALL)     echo "$url|0|0" ;;       # url | start_index | shuffle
        SHUFFLE) echo "$url|0|1" ;;       # url | start_index | shuffle
        VIDEO)   echo "$url|${idx_sel}|0" ;;  # url | start_index | shuffle
        *)       return 1 ;;
    esac
}

# Display video metadata in a formatted way
show_video_metadata() {
    local title="$1"
    local channel="$2"
    local views="$3"
    local upload_date="$4"
    local duration="$5"

    echo ""
    log_info "Title:    $title"
    log_info "Channel:  $channel"
    log_info "Views:    $(format_views "$views")"
    
    if [[ -n "$upload_date" ]]; then
        log_info "Uploaded: ${upload_date:0:4}-${upload_date:4:2}-${upload_date:6:2}"
    fi
    
    log_info "Duration: $(format_duration "$duration")"
    echo ""
}

# Get playlist action from user via fzf
# Returns: url, start_index, shuffle_flag on separate lines
# Usage: read -r url start_idx shuffle < <(get_playlist_action "MyPlaylist" "url" "video_tsv")
get_playlist_action() {
    local name="$1"
    local url="$2"
    local video_tsv="$3"

    # Build fzf input with special options and video list
    local fzf_input="" idx=0 title channel duration line
    fzf_input+="ALL"$'\t'""$'\t'"▶  Play All"$'\n'
    fzf_input+="SHUFFLE"$'\t'""$'\t'"🔀  Shuffle All"$'\n'

    while IFS=$'\t' read -r title channel duration; do
        ((idx++)) || true
        line=$(_format_playlist_row "$idx" "$title" "$channel" "$duration")
        fzf_input+="VIDEO"$'\t'"${idx}"$'\t'"${line}"$'\n'
    done <<< "$video_tsv"

    # Show fzf picker
    local header selected
    header=$(_build_playlist_header)
    
    selected=$(printf '%s' "$fzf_input" | fzf \
        --delimiter=$'\t' \
        --with-nth=3 \
        --prompt="${name}> " \
        --height="$FZF_HEIGHT" \
        --border \
        --header="Playlist: ${name}  (Enter: play all / shuffle all / jump to a track)") || return 1

    [[ -z "$selected" ]] && return 1

    # Parse the selected row and return action details
    local control idx_sel
    IFS=$'\t' read -r control idx_sel _ <<< "$selected"

    case "$control" in
        ALL)     echo "$url"; echo ""; echo "0" ;;
        SHUFFLE) echo "$url"; echo ""; echo "1" ;;
        VIDEO)   echo "$url"; echo "$idx_sel"; echo "0" ;;
        *)       return 1 ;;
    esac
}

# Library browse using fzf - select a playlist
# Returns: file path to selected playlist on stdout
library_browse() {
    local files
    
    files=$(find "$PipePlay_PLAYLISTS_DIR" -maxdepth 1 -name '*.json' -print 2>/dev/null) || {
        log_error "Failed to list playlists"
        return 1
    }

    if [[ -z "$files" ]]; then
        log_info "No saved playlists yet. Try: pipeplay --save-playlist <url>"
        return 1
    fi

    local entries="" f pname
    while read -r f; do
        [[ -f "$f" ]] || continue
        pname=$(jq -r '.name' "$f" 2>/dev/null) || continue
        entries+="${pname}"$'\t'"${f}"$'\n'
    done <<< "$files"

    if [[ -z "$entries" ]]; then
        log_error "No valid playlist files found"
        return 1
    fi

    local selected
    selected=$(printf '%s' "$entries" | fzf \
        --delimiter=$'\t' \
        --with-nth=1 \
        --prompt="library> " \
        --height="60%" \
        --border \
        --header="Saved Playlists") || return 1

    [[ -z "$selected" ]] && return 1
    
    cut -f2 <<< "$selected"
}
