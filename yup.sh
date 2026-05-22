#!/usr/bin/env bash

# Enforce strict error handling
set -euo pipefail

# Constants
readonly DELAY=86400 
readonly CURRENT_TIME=$(date +%s)

# ANSI color codes for standard CLI feedback
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

# Ensure dependencies are met
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error:${NC} 'jq' is required. Please install it (e.g., pacman -S jq)." >&2
    exit 1
fi

# Function to check AUR modification time
check_aur_modified_time() {
    local pkg="$1"
    local last_modified

    # Added -Sf to fail-fast on server errors (500/502) preventing pipefail crashes
    last_modified=$(curl -sSfL "https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=${pkg}" | jq -r '.results[0].LastModified // empty')
    
    if [[ -z "$last_modified" || "$last_modified" == "null" ]]; then
        echo "unknown"
        return
    fi

    local time_diff=$(( CURRENT_TIME - last_modified ))
    if (( time_diff >= DELAY )); then
        echo "safe"
    else
        echo "unsafe"
    fi
}

# State variables
is_update=0
is_passthrough=0
declare -a packages=()

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        -Syu|-Syyu|-Su|--sysupgrade)
            is_update=1
            ;;
        # Added -S[cilsw]* to safely passthrough commands like -Si, -Sc, -Sl
        -[RQUYPG]*|-S[cilsw]*|--remove|--query|--deptest|--show)
            is_passthrough=1
            ;;
        -*)
            # Other flags, ignored by parser but passed to yay
            ;;
        *)
            packages+=("$arg")
            ;;
    esac
done

# 1. System Update Logic
if (( is_update )); then
    echo -e "${YELLOW}Checking pending AUR updates against the 24-hour rule...${NC}"
    
    declare -a ignore_args=()
    # Read output into array safely, suppressing errors if no updates exist
    mapfile -t aur_updates < <(yay -Qu --aur 2>/dev/null | awk '{print $1}' || true)

    if (( ${#aur_updates[@]} > 0 )); then
        for pkg in "${aur_updates[@]}"; do
            # Skip empty lines
            [[ -z "$pkg" ]] && continue 

            status=$(check_aur_modified_time "$pkg")
            if [[ "$status" == "unsafe" ]]; then
                echo -e "${YELLOW}[IGNORE]${NC} $pkg (Modified within 24h)"
                ignore_args+=("--ignore" "$pkg")
            elif [[ "$status" == "safe" ]]; then
                echo -e "${GREEN}[SAFE]${NC} $pkg"
            fi
        done
    else
        echo "No pending AUR updates."
    fi

    echo "Proceeding to yay..."
    exec yay "$@" "${ignore_args[@]}"
fi

# 2. Pass-through Logic
if (( is_passthrough )); then
    exec yay "$@"
fi

# 3. Explicit Installation Logic
if (( ${#packages[@]} > 0 )); then
    unsafe_count=0
    for pkg in "${packages[@]}"; do
        status=$(check_aur_modified_time "$pkg")
        
        if [[ "$status" == "unsafe" ]]; then
            echo -e "${RED}[WARNING]${NC} $pkg was modified under 24 hours ago."
            (( unsafe_count++ ))
        elif [[ "$status" == "safe" ]]; then
            echo -e "${GREEN}[OK]${NC} $pkg is safe or in official repos."
        fi
    done

    if (( unsafe_count > 0 )); then
        echo -e "${RED}Aborting: Unsafe packages detected.${NC}" >&2
        exit 1
    fi
fi

# Fallback execution
exec yay "$@"
