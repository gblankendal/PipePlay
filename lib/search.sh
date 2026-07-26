#!/usr/bin/env bash
#
# search.sh - YouTube search and metadata fetching
#
# Handles yt-dlp invocations for searching, fetching metadata, and resolving URLs.
#

# Search for a video and return the first result's ID
# Resolves the search to a concrete video ID before playing (ensures -loop works correctly)
# Usage: vid=$(search_youtube "search query") && play_video "https://youtu.be/$vid"
search_youtube() {
    local query="$1"
    [[ -z "$query" ]] && die "search_youtube: Query cannot be empty"
    
    log_info "Searching YouTube for: $query"
    
    local json id
    json=$(yt-dlp --flat-playlist -J "ytsearch1:${query}" 2>/dev/null) || {
        log_error "Failed to search YouTube"
        return 1
    }
    
    if [[ -z "$json" ]]; then
        log_error "No search results found for: $query"
        return 1
    fi
    
    id=$(jq -r '.entries[0].id // empty' <<< "$json" 2>/dev/null) || {
        log_error "Failed to parse search results"
        return 1
    }
    
    if [[ -z "$id" ]]; then
        log_error "No search results found for: $query"
        return 1
    fi
    
    echo "$id"
}

# Fetch full metadata for a single video
# Returns JSON on stdout
# Usage: metadata=$(fetch_video_metadata "https://youtu.be/dQw4w9WgXcQ")
fetch_video_metadata() {
    local url="$1"
    [[ -z "$url" ]] && die "fetch_video_metadata: URL is required"
    
    log_info "Fetching video metadata..."
    
    yt-dlp -J "$url" 2>/dev/null || {
        log_warn "Failed to fetch metadata for: $url"
        return 1
    }
}

# Fetch playlist metadata (flat, without individual video fetches)
# Returns JSON on stdout
# Usage: metadata=$(fetch_playlist_metadata "https://www.youtube.com/playlist?list=...")
fetch_playlist_metadata() {
    local url="$1"
    [[ -z "$url" ]] && die "fetch_playlist_metadata: URL is required"
    
    log_info "Fetching playlist metadata..."
    
    yt-dlp --flat-playlist -J "$url" 2>/dev/null || {
        log_error "Failed to fetch playlist: $url"
        return 1
    }
}

# Fetch a limited number of search results
# Returns JSON on stdout
# Usage: results=$(search_youtube_batch "query" 10)
search_youtube_batch() {
    local query="$1"
    local limit="${2:-$SEARCH_RESULTS_LIMIT}"
    [[ -z "$query" ]] && die "search_youtube_batch: Query cannot be empty"
    
    log_info "Searching YouTube for: $query (limit: $limit results)"
    
    local json
    json=$(yt-dlp --flat-playlist -J "ytsearch${limit}:${query}" 2>/dev/null) || {
        log_error "Failed to search YouTube"
        return 1
    }
    
    if [[ -z "$json" ]]; then
        log_error "No results found"
        return 1
    fi
    
    echo "$json"
}

# Extract video ID from URL
# Usage: id=$(extract_video_id "https://youtu.be/dQw4w9WgXcQ")
extract_video_id() {
    local url="$1"
    [[ -z "$url" ]] && return 1
    
    # Try youtu.be short format
    if [[ "$url" =~ youtu\.be/([A-Za-z0-9_-]{11}) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    # Try youtube.com format
    if [[ "$url" =~ v=([A-Za-z0-9_-]{11}) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    # If it's already an ID
    if is_video_id "$url"; then
        echo "$url"
        return 0
    fi
    
    return 1
}

# Get a video URL from various input formats
# Handles: video IDs, full URLs, search queries
# Returns: canonical youtu.be URL on stdout, or returns 1
resolve_video_input() {
    local input="$1"
    [[ -z "$input" ]] && die "resolve_video_input: Input cannot be empty"
    
    # Check if it's a full URL
    if is_http_url "$input"; then
        local vid
        vid=$(extract_video_id "$input") || return 1
        echo "https://youtu.be/$vid"
        return 0
    fi
    
    # Check if it's a video ID
    if is_video_id "$input"; then
        echo "https://youtu.be/$input"
        return 0
    fi
    
    # Otherwise treat as search query
    local vid
    vid=$(search_youtube "$input") || return 1
    echo "https://youtu.be/$vid"
    return 0
}

# Clear yt-dlp's cache (disposable and regenerates on demand)
clear_ytdlp_cache() {
    if command_exists yt-dlp; then
        yt-dlp --rm-cache-dir >/dev/null 2>&1 || log_warn "Failed to clear yt-dlp cache"
    fi
}
