#!/usr/bin/env bash
#
# logging.sh - Centralized logging functions for PipePlay
#
# Provides consistent, formatted output for info, warnings, and errors.
# All log output goes to stderr to avoid polluting stdout.
#

# Color codes for terminal output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_BLUE='\033[0;34m'

# Check if output supports colors
_supports_colors() {
    [[ -t 2 ]] && [[ "${TERM:-}" != "dumb" ]]
}

# Internal function to emit log messages
_log_message() {
    local level="$1"
    local color="$2"
    shift 2
    local message="$*"

    if _supports_colors; then
        printf '%b[%s]%b %s\n' "$color" "$level" "$COLOR_RESET" "$message" >&2
    else
        printf '[%s] %s\n' "$level" "$message" >&2
    fi
}

# Log an informational message
log_info() {
    _log_message "INFO" "$COLOR_BLUE" "$@"
}

# Log a warning message
log_warn() {
    _log_message "WARN" "$COLOR_YELLOW" "$@"
}

# Log an error message
log_error() {
    _log_message "ERROR" "$COLOR_RED" "$@"
}

# Log a success message
log_success() {
    _log_message "OK" "$COLOR_GREEN" "$@"
}

# Log an error and exit
# Usage: die "message"
die() {
    log_error "$@"
    exit 1
}

# Log an error and exit with custom code
# Usage: die_with_code 42 "message"
die_with_code() {
    local code="$1"
    shift
    log_error "$@"
    exit "$code"
}

# Assert that a command succeeded
# Usage: assert_success "mpv" "Failed to start video player"
assert_success() {
    local cmd="$1"
    local error_msg="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "Assertion failed: $error_msg"
    fi
}
