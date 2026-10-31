#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_dir/lib/ui.sh"
source "$repo_dir/lib/playlists.sh"

PLAYLIST_PICKER_WIDTH_TITLE=50
PLAYLIST_PICKER_WIDTH_CHANNEL=18
FZF_HEIGHT=90%

truncate_title() { printf '%s' "$1"; }
format_duration() { printf '%s' "$1"; }

# Return the requested picker row while consuming the input as fzf would.
fzf() {
    local rows
    rows=$(cat)
    case "$selection" in
        VIDEO) printf '%s\n' "$rows" | awk -F '\t' '$1 == "VIDEO" && $2 == 6 { print; exit }' ;;
        ALL|SHUFFLE) printf '%s\n' "$rows" | awk -F '\t' -v choice="$selection" '$1 == choice { print; exit }' ;;
        CANCEL) return 1 ;;
    esac
}

play_playlist() { played="$1|$2|$3"; }

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
playlist_file="$tmp_dir/playlist.json"
playlist_url='https://www.youtube.com/playlist?list=TVWATCHLATER'
jq -n --arg url "$playlist_url" '{
    name: "TV watch later",
    source_url: $url,
    videos: [range(1; 7) | {title: ("Video " + tostring), channel: "Channel", duration: 60}]
}' > "$playlist_file"

selection=VIDEO
played=''
browse_saved_playlist "$playlist_file"
[[ "$played" == "$playlist_url|6|0" ]]

selection=ALL
browse_saved_playlist "$playlist_file"
[[ "$played" == "$playlist_url||0" ]]

selection=SHUFFLE
browse_saved_playlist "$playlist_file"
[[ "$played" == "$playlist_url||1" ]]

selection=CANCEL
played=''
browse_saved_playlist "$playlist_file"
[[ -z "$played" ]]

extract_playlist_id() { printf '%s' TVWATCHLATER; }
canonical_playlist_url() { printf '%s' "$playlist_url"; }
fetch_playlist_metadata() {
    jq '{title: .name, entries: .videos}' "$playlist_file"
}

selection=VIDEO
browse_adhoc_playlist "$playlist_url"
[[ "$played" == "$playlist_url|6|0" ]]

echo 'Playlist selection works'
