#!/usr/bin/env bash
#
# playlists.sh - Playlist management functions
#
# Handles saving, loading, syncing, and browsing user's saved playlists.
#

# shellcheck disable=SC2154  # Variables from config.sh are set by sourcing main script
# Global variables referenced but not assigned in this module:
# PipePlay_PLAYLISTS_DIR, PipePlay_DATA_DIR

# Find a saved playlist file by name, slug, or partial match
# Returns the file path on stdout, or 1 if not found
# Usage: file=$(find_playlist_by_name "my_playlist")
find_playlist_by_name() {
    local name="$1"
    [[ -z "$name" ]] && return 1
    
    local slug file
    slug=$(slugify "$name")
    
    # Try exact slug match first
    file="$PipePlay_PLAYLISTS_DIR/${slug}.json"
    if [[ -f "$file" ]]; then
        echo "$file"
        return 0
    fi
    
    # Try to find by stored name (case-insensitive slug match)
    for f in "$PipePlay_PLAYLISTS_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        local stored_name
        stored_name=$(jq -r '.name' "$f" 2>/dev/null) || continue
        if [[ "$(slugify "$stored_name")" == "$slug" ]]; then
            echo "$f"
            return 0
        fi
    done
    
    return 1
}

# Save a new playlist from a URL
# Creates a JSON file with metadata and video list
# Usage: save_playlist "https://www.youtube.com/playlist?list=PL..."
save_playlist() {
    local input="$1"
    [[ -z "$input" ]] && die "save_playlist: URL or ID is required"
    
    local pid url json title slug outfile videos count existing_pid
    
    # Parse the playlist ID
    pid=$(extract_playlist_id "$input") || die "Invalid playlist URL or ID: $input"
    url=$(canonical_playlist_url "$pid")
    
    # Fetch playlist metadata
    json=$(fetch_playlist_metadata "$url") || return 1
    
    if [[ -z "$json" ]]; then
        log_error "Failed to fetch playlist"
        return 1
    fi
    
    # Extract title and create slug
    title=$(jq -r '.title // "Untitled Playlist"' <<< "$json")
    slug=$(slugify "$title")
    [[ -z "$slug" ]] && slug="$pid"
    outfile="$PipePlay_PLAYLISTS_DIR/${slug}.json"
    
    # Handle slug collision: reuse only if it's the same playlist
    if [[ -f "$outfile" ]]; then
        existing_pid=$(jq -r '.playlist_id // empty' "$outfile" 2>/dev/null)
        if [[ -n "$existing_pid" && "$existing_pid" != "$pid" ]]; then
            slug="${slug}_${pid: -6}"
            outfile="$PipePlay_PLAYLISTS_DIR/${slug}.json"
        fi
    fi
    
    # Extract video list
    videos=$(jq '[.entries[]? | {
        id: (.id // ""),
        title: (.title // "Unknown"),
        channel: (.channel // .uploader // "Unknown"),
        duration: (.duration // 0),
        view_count: (.view_count // 0),
        url: ("https://youtu.be/" + (.id // ""))
    }]' <<< "$json") || die "Failed to parse playlist videos"
    
    # Write to file atomically
    local tmpfile
    tmpfile=$(make_temp_file)
    # shellcheck disable=SC2064  # Deliberately using double quotes so variable is evaluated
    trap "cleanup_tempfile $tmpfile" RETURN
    
    jq -n \
        --arg name "$title" \
        --arg pid "$pid" \
        --arg url "$url" \
        --argjson videos "$videos" \
        --arg updated "$(date -Iseconds)" \
        '{name: $name, playlist_id: $pid, source_url: $url, videos: $videos, updated_at: $updated}' \
        > "$tmpfile" || die "Failed to create playlist file"
    
    mv "$tmpfile" "$outfile" || die "Failed to save playlist"
    
    count=$(jq 'length' <<< "$videos")
    log_success "Saved playlist '${title}' (${count} videos) -> ${outfile}"
}

# Load and display a saved playlist for browsing
# Usage: browse_saved_playlist "path/to/playlist.json"
browse_saved_playlist() {
    local file="$1"
    [[ -f "$file" ]] || die "Playlist file not found: $file"
    
    local name url videos_tsv
    name=$(jq -r '.name' "$file") || die "Invalid playlist file"
    url=$(jq -r '.source_url' "$file") || die "Invalid playlist file"
    videos_tsv=$(jq -r '.videos[] | [(.title), (.channel), (.duration)] | @tsv' "$file") || die "Failed to read playlist videos"
    
    # Get user's action from fzf picker
    local pl_url start_idx shuffle_flag
    read -r pl_url start_idx shuffle_flag < <(get_playlist_action "$name" "$url" "$videos_tsv") || return 0
    
    # Play based on the selected action
    play_playlist "$pl_url" "$start_idx" "$shuffle_flag"
}

# Resume playback of a saved playlist (uses mpv's resume data)
# Usage: resume_saved_playlist "path/to/playlist.json"
resume_saved_playlist() {
    local file="$1"
    [[ -f "$file" ]] || die "Playlist file not found: $file"
    
    local name url
    name=$(jq -r '.name' "$file") || die "Invalid playlist file"
    url=$(jq -r '.source_url' "$file") || die "Invalid playlist file"
    
    log_info "Resuming: $name"
    play_playlist "$url" "" 0
}

# Sync (refetch) a saved playlist and report new videos
# Usage: sync_saved_playlist "path/to/playlist.json"
sync_saved_playlist() {
    local file="$1"
    [[ -f "$file" ]] || die "Playlist file not found: $file"
    
    local pname url json old_ids new_ids videos added tmpfile
    
    pname=$(jq -r '.name' "$file") || die "Invalid playlist file"
    url=$(jq -r '.source_url' "$file") || die "Invalid playlist file"
    
    log_info "Syncing: $pname ..."
    
    # Get old video IDs
    old_ids=$(jq -r '.videos[].id' "$file" | sort) || die "Failed to read old video list"
    
    # Fetch fresh metadata
    json=$(fetch_playlist_metadata "$url") || return 1
    
    # Extract new video list
    videos=$(jq '[.entries[]? | {
        id: (.id // ""),
        title: (.title // "Unknown"),
        channel: (.channel // .uploader // "Unknown"),
        duration: (.duration // 0),
        view_count: (.view_count // 0),
        url: ("https://youtu.be/" + (.id // ""))
    }]' <<< "$json") || die "Failed to parse playlist"
    
    # Compare and count new videos
    new_ids=$(jq -r '.[].id' <<< "$videos" | sort) || die "Failed to read new video IDs"
    added=$(comm -13 <(echo "$old_ids") <(echo "$new_ids") | grep -c . || true)
    
    # Update the file atomically
    tmpfile=$(make_temp_file)
    # shellcheck disable=SC2064  # Deliberately using double quotes so variable is evaluated
    trap "cleanup_tempfile $tmpfile" RETURN
    
    jq --argjson videos "$videos" --arg updated "$(date -Iseconds)" \
        '.videos = $videos | .updated_at = $updated' "$file" > "$tmpfile" || die "Failed to update playlist"
    
    mv "$tmpfile" "$file" || die "Failed to save updated playlist"
    
    if [[ "$added" -gt 0 ]]; then
        log_success "$pname: +${added} new video(s)"
    else
        log_success "$pname: up to date"
    fi
}

# Shuffle and play a saved playlist
# Usage: shuffle_saved_playlist "path/to/playlist.json"
shuffle_saved_playlist() {
    local file="$1"
    [[ -f "$file" ]] || die "Playlist file not found: $file"
    
    local url
    url=$(jq -r '.source_url' "$file") || die "Invalid playlist file"
    
    log_info "Shuffling: $(jq -r '.name' "$file")"
    play_playlist "$url" "" 1
}

# Get list of all saved playlist files
# Returns: file paths, one per line
list_all_playlists() {
    find "$PipePlay_PLAYLISTS_DIR" -maxdepth 1 -name '*.json' -print 2>/dev/null || return 1
}

# Sync all saved playlists (or specific one if name provided)
# Usage: sync_all_playlists or sync_all_playlists "playlist_name"
sync_all_playlists() {
    local name="${1:-}"
    local files
    
    if [[ -n "$name" ]]; then
        files=$(find_playlist_by_name "$name") || {
            log_error "No playlist matching: $name"
            return 1
        }
    else
        files=$(list_all_playlists) || {
            log_error "No saved playlists found"
            return 1
        }
    fi
    
    if [[ -z "$files" ]]; then
        log_error "No playlists to sync"
        return 1
    fi
    
    local file
    while read -r file; do
        [[ -f "$file" ]] && sync_saved_playlist "$file"
    done <<< "$files"
}

# Handle an ad-hoc (unsaved) playlist: fetch and browse
# Usage: browse_adhoc_playlist "https://www.youtube.com/playlist?list=..."
browse_adhoc_playlist() {
    local query="$1"
    [[ -z "$query" ]] && die "Playlist URL or ID is required"
    
    local pid url json title videos_tsv
    
    pid=$(extract_playlist_id "$query") || die "Could not parse playlist ID from: $query"
    url=$(canonical_playlist_url "$pid")
    
    json=$(fetch_playlist_metadata "$url") || return 1
    
    title=$(jq -r '.title // "Untitled Playlist"' <<< "$json") || die "Failed to read playlist title"
    videos_tsv=$(jq -r '.entries[]? |
        [(.title // "Unknown"), (.channel // .uploader // "Unknown"), (.duration // 0)] | @tsv' <<< "$json") || die "Failed to parse videos"
    
    # Get user's action from fzf picker
    local pl_url start_idx shuffle_flag
    read -r pl_url start_idx shuffle_flag < <(get_playlist_action "$title" "$url" "$videos_tsv") || return 0
    
    # Play based on the selected action
    play_playlist "$pl_url" "$start_idx" "$shuffle_flag"
}
