#!/usr/bin/env bash
#
# cache.sh - Cache and cleanup management
#
# Handles temporary files, watch_later resume data, and session cleanup.
#

# shellcheck disable=SC2154  # Variables from config.sh are set by sourcing main script
# Global variables (set by config.sh which is sourced before this module)
# PipePlay_PLAYLISTS_DIR, PipePlay_CACHE_DIR, PipePlay_WATCH_LATER_DIR, PipePlay_DATA_DIR, CACHE_MAX_AGE_DAYS

# Conservative session cleanup (runs on every exit)
# Only removes truly disposable data or clearly stale entries
cleanup_session() {
    log_info "Cleaning up..."
    
    # 1. Clear yt-dlp's disposable cache (regenerates on demand)
    clear_ytdlp_cache
    
    # 2. Remove stray .tmp files left by interrupted --sync operations
    if [[ -d "$PipePlay_PLAYLISTS_DIR" ]]; then
        find "$PipePlay_PLAYLISTS_DIR" -maxdepth 1 -name '*.tmp' -delete 2>/dev/null || true
    fi
    
    # 3. Clear our scratch cache directory
    if [[ -d "$PipePlay_CACHE_DIR" ]]; then
        find "$PipePlay_CACHE_DIR" -mindepth 1 -delete 2>/dev/null || true
    fi
    
    # 4. Prune old, likely-abandoned mpv resume data
    if [[ -d "$PipePlay_WATCH_LATER_DIR" ]]; then
        find "$PipePlay_WATCH_LATER_DIR" -type f -mtime "+${CACHE_MAX_AGE_DAYS}" -delete 2>/dev/null || true
    fi
}

# Aggressive on-demand cleanup (user ran `pipeplay --clean`)
# Wipes ALL resume points, not just stale ones
# Saved playlists are NEVER touched
clean_all_cache() {
    log_info "Performing aggressive cache cleanup..."
    
    local before after
    before=$(du -sh "$PipePlay_DATA_DIR" 2>/dev/null | cut -f1 || echo "?")
    
    # Clear yt-dlp cache
    clear_ytdlp_cache
    
    # Remove all .tmp files
    if [[ -d "$PipePlay_PLAYLISTS_DIR" ]]; then
        find "$PipePlay_PLAYLISTS_DIR" -maxdepth 1 -name '*.tmp' -delete 2>/dev/null || true
    fi
    
    # Clear scratch cache
    if [[ -d "$PipePlay_CACHE_DIR" ]]; then
        find "$PipePlay_CACHE_DIR" -mindepth 1 -delete 2>/dev/null || true
    fi
    
    # Clear ALL resume points (not just stale ones)
    if [[ -d "$PipePlay_WATCH_LATER_DIR" ]]; then
        find "$PipePlay_WATCH_LATER_DIR" -type f -delete 2>/dev/null || true
    fi
    
    after=$(du -sh "$PipePlay_DATA_DIR" 2>/dev/null | cut -f1 || echo "?")
    log_success "Done. Saved playlists untouched. (~${before} -> ~${after})"
}

# Get total size of PipePlay data directory
get_data_dir_size() {
    du -sh "$PipePlay_DATA_DIR" 2>/dev/null | cut -f1 || echo "unknown"
}

# Report cache statistics
report_cache_stats() {
    log_info "PipePlay cache statistics:"
    log_info "  Data directory: $PipePlay_DATA_DIR"
    log_info "  Total size: $(get_data_dir_size)"
    
    if [[ -d "$PipePlay_PLAYLISTS_DIR" ]]; then
        local count
        count=$(find "$PipePlay_PLAYLISTS_DIR" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l)
        log_info "  Saved playlists: $count"
    fi
    
    if [[ -d "$PipePlay_WATCH_LATER_DIR" ]]; then
        local count
        count=$(find "$PipePlay_WATCH_LATER_DIR" -type f 2>/dev/null | wc -l)
        log_info "  Resume points: $count"
    fi
}

# Clean up a specific temporary file safely
cleanup_tempfile() {
    local file="$1"
    if [[ -f "$file" ]]; then
        rm -f "$file" 2>/dev/null || true
    fi
}

# Clean up a specific temporary directory safely
cleanup_tempdir() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        rm -rf "$dir" 2>/dev/null || true
    fi
}
