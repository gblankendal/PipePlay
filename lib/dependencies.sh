#!/usr/bin/env bash
#
# dependencies.sh - Dependency checking and validation
#
# Verifies that all required external commands are available before starting.
#

# List of required commands
readonly REQUIRED_COMMANDS=(mpv yt-dlp jq fzf)

# List of optional commands that might be used in advanced scenarios
# shellcheck disable=SC2034  # OPTIONAL_COMMANDS may be used externally
readonly OPTIONAL_COMMANDS=(curl grep sed awk)

# Check if a single command is available
command_exists() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

# Check all required dependencies
check_required_deps() {
    local missing=()
    local cmd
    
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tool(s): ${missing[*]}"
        log_error ""
        log_error "Please install the following packages and ensure they're on your PATH:"
        log_error ""
        _print_install_instructions "${missing[@]}"
        log_error ""
        log_error "After installation, verify with: command -v ${missing[0]}"
        return 1
    fi
    
    return 0
}

# Print install instructions based on system
_print_install_instructions() {
    local cmd
    for cmd in "$@"; do
        case "$cmd" in
            mpv)
                log_error "  sudo apt install mpv"
                ;;
            yt-dlp)
                log_error "  sudo apt install pipx"
                log_error "  pipx install yt-dlp"
                log_error "  pipx ensurepath"
                ;;
            jq)
                log_error "  sudo apt install jq"
                ;;
            fzf)
                log_error "  sudo apt install fzf"
                ;;
            curl)
                log_error "  sudo apt install curl"
                ;;
            grep|sed|awk)
                log_error "  sudo apt install grep sed gawk"
                ;;
        esac
    done
}

# Check all dependencies and die if any are missing
verify_dependencies() {
    if ! check_required_deps; then
        die "Dependency check failed"
    fi
}

# Get versions of installed commands (for debugging)
print_dependency_versions() {
    local cmd
    log_info "Checking dependency versions..."
    
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if command_exists "$cmd"; then
            case "$cmd" in
                mpv)
                    log_info "  $cmd: $(mpv --version | head -1)"
                    ;;
                yt-dlp)
                    log_info "  $cmd: $(yt-dlp --version | head -1)"
                    ;;
                jq)
                    log_info "  $cmd: $(jq --version)"
                    ;;
                fzf)
                    log_info "  $cmd: $(fzf --version)"
                    ;;
            esac
        fi
    done
}
