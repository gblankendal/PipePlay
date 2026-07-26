#!/usr/bin/env bash
#
# utils.sh - Common utility functions for PipePlay
#
# Provides string manipulation, formatting, and helper functions.
#

# Format large view counts (35378567 -> 35.3M, 999 -> 999, 0/empty -> "-")
format_views() {
    local n="${1:-}"
    if [[ -z "$n" || "$n" == "null" ]] || ! [[ "$n" =~ ^[0-9]+$ ]] || [[ "$n" -eq 0 ]]; then
        echo "-"
        return 0
    fi
    awk -v n="$n" 'BEGIN {
        if (n >= 1000000000) printf "%.1fB", n/1000000000
        else if (n >= 1000000) printf "%.1fM", n/1000000
        else if (n >= 1000) printf "%.1fK", n/1000
        else printf "%d", n
    }'
}

# Format duration in seconds to HH:MM:SS or MM:SS
# (158 -> 2:38, 3725 -> 1:02:05, 0/empty -> "-")
format_duration() {
    local secs="${1:-}"
    if [[ -z "$secs" || "$secs" == "null" ]] || ! [[ "$secs" =~ ^[0-9]+$ ]] || [[ "$secs" -eq 0 ]]; then
        echo "-"
        return 0
    fi
    local h=$((secs / 3600))
    local m=$(((secs % 3600) / 60))
    local s=$((secs % 60))
    if [[ $h -gt 0 ]]; then
        printf "%d:%02d:%02d" "$h" "$m" "$s"
    else
        printf "%d:%02d" "$m" "$s"
    fi
}

# Truncate text to a maximum length with ellipsis
# Usage: truncate_title "text" [maxlen]
truncate_title() {
    local text="$1"
    local maxlen="${2:-57}"
    if [[ ${#text} -gt $maxlen ]]; then
        echo "${text:0:$((maxlen - 1))}…"
    else
        echo "$text"
    fi
}

# Convert a title to a URL-safe slug
# "Physics Wallah - Electrostatics!" -> "physics_wallah_electrostatics"
slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g'
}

# Check if a string looks like a YouTube playlist URL or ID
is_playlist() {
    local q="$1"
    [[ "$q" == *"list="* ]] && return 0
    [[ "$q" =~ ^(PL|UU|LL|FL|RD|OL)[A-Za-z0-9_-]{10,}$ ]] && return 0
    return 1
}

# Extract playlist ID from a URL or return it if it's a bare ID
extract_playlist_id() {
    local q="$1"
    if [[ "$q" == *"list="* ]]; then
        grep -oP 'list=\K[^&]+' <<< "$q" || return 1
    else
        echo "$q"
    fi
}

# Build a canonical playlist URL from a playlist ID
canonical_playlist_url() {
    local pid="$1"
    echo "https://www.youtube.com/playlist?list=$pid"
}

# Check if a string is a valid YouTube video ID (11 alphanumeric, -, or _)
is_video_id() {
    local id="$1"
    [[ "$id" =~ ^[A-Za-z0-9_-]{11}$ ]]
}

# Safely create a temporary file
# Usage: tmpfile=$(make_temp_file) or make_temp_file > file.txt
make_temp_file() {
    local tmpfile
    tmpfile=$(mktemp) || die "Failed to create temporary file"
    echo "$tmpfile"
}

# Safely create a temporary directory
# Usage: tmpdir=$(make_temp_dir)
make_temp_dir() {
    local tmpdir
    tmpdir=$(mktemp -d) || die "Failed to create temporary directory"
    echo "$tmpdir"
}

# Check if a URL is HTTP/HTTPS
is_http_url() {
    local url="$1"
    [[ "$url" =~ ^https?:// ]]
}

# Safely remove a temporary file if it exists
# Usage: cleanup_tempfile "$tmpfile"
cleanup_tempfile() {
    local file="$1"
    [[ -f "$file" ]] && rm -f "$file"
}

# Safely remove a temporary directory if it exists
# Usage: cleanup_tempdir "$tmpdir"
cleanup_tempdir() {
    local dir="$1"
    [[ -d "$dir" ]] && rm -rf "$dir"
}

# Trim leading/trailing whitespace from a string
trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace
    var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace
    echo "$var"
}

# Simple retry logic for network operations
# Usage: retry 3 yt-dlp --info-json "https://youtu.be/..."
# Will retry up to N times before giving up
retry() {
    local max_attempts="$1"
    shift
    local attempt=1

    while true; do
        if "$@"; then
            return 0
        fi
        
        if [[ $attempt -ge $max_attempts ]]; then
            log_error "Command failed after $max_attempts attempts: $*"
            return 1
        fi
        
        log_warn "Attempt $attempt/$max_attempts failed, retrying..."
        ((attempt++))
        sleep 2
    done
}
