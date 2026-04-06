#!/usr/bin/env bash
# Claude Code status line script
# Displays: [ProjectName] 🌿 branch-name | ▓▓░░░░░░░░ 25% ctx

# --- ANSI colors ---
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

COLOR_PROJECT="\033[38;5;75m"   # Soft blue for project name
COLOR_BRANCH="\033[38;5;114m"   # Soft green for branch
COLOR_SEP="\033[38;5;240m"      # Dark gray for separators
COLOR_CTX_GREEN="\033[38;5;76m"  # Green  (< 70%)
COLOR_CTX_YELLOW="\033[38;5;220m" # Yellow (70-89%)
COLOR_CTX_RED="\033[38;5;196m"  # Red    (>= 90%)
COLOR_BAR_FILL="\033[38;5;246m" # Gray filled bar block
COLOR_BAR_EMPTY="\033[38;5;235m" # Dark gray empty bar block

# --- Parse stdin JSON ---
input=$(cat)

# Project name: basename of project_dir, fallback to cwd basename
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // .cwd // empty')
if [ -n "$project_dir" ]; then
    project_name=$(basename "$project_dir")
else
    project_name="unknown"
fi

# Context window usage (pre-calculated percentage used)
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Total tokens used (input + cache + output from current usage)
used_tokens=$(echo "$input" | jq -r '
  .context_window.current_usage
  | if . then
      (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) + (.output_tokens // 0)
    else empty end
')

# Rate limits (only present for Claude.ai Pro/Max subscribers)
rate_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rate_5h_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rate_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
rate_7d_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
now_epoch=$(date +%s)

# --- Git branch with 5-second file cache ---
# Use the cwd from the JSON input as the working directory
working_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

git_branch=""
if [ -n "$working_dir" ] && [ -d "$working_dir" ]; then
    cache_dir="${TMPDIR:-/tmp}/claude_statusline_cache"
    mkdir -p "$cache_dir" 2>/dev/null

    # Build a safe cache key from the working directory path
    cache_key=$(printf '%s' "$working_dir" | tr '/' '_' | tr ' ' '_')
    cache_file="$cache_dir/git_branch_${cache_key}"

    now=$(date +%s)
    cache_valid=0

    if [ -f "$cache_file" ]; then
        cache_mtime=$(stat -f '%m' "$cache_file" 2>/dev/null || stat -c '%Y' "$cache_file" 2>/dev/null)
        if [ -n "$cache_mtime" ] && [ $((now - cache_mtime)) -lt 5 ]; then
            cache_valid=1
        fi
    fi

    if [ "$cache_valid" -eq 1 ]; then
        git_branch=$(cat "$cache_file" 2>/dev/null)
    else
        git_branch=$(git -C "$working_dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
                     || git -C "$working_dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
        printf '%s' "$git_branch" > "$cache_file" 2>/dev/null
    fi
fi

# --- Build progress bar (10 blocks) ---
build_bar() {
    local pct="$1"
    local filled=0
    local total=10

    if [ -n "$pct" ]; then
        filled=$(echo "$pct $total" | awk '{v=int($1*$2/100+0.5); if(v>$2) v=$2; print v}')
    fi

    local empty=$((total - filled))
    local bar=""
    local i

    for i in $(seq 1 "$filled"); do
        bar="${bar}▓"
    done
    for i in $(seq 1 "$empty"); do
        bar="${bar}░"
    done

    printf '%s' "$bar"
}

# --- Choose context color ---
ctx_color="$COLOR_CTX_GREEN"
if [ -n "$used_pct" ]; then
    # Use awk for float comparison
    bucket=$(echo "$used_pct" | awk '{if($1>=90) print "red"; else if($1>=70) print "yellow"; else print "green"}')
    case "$bucket" in
        red)    ctx_color="$COLOR_CTX_RED"    ;;
        yellow) ctx_color="$COLOR_CTX_YELLOW" ;;
        *)      ctx_color="$COLOR_CTX_GREEN"  ;;
    esac
fi

# --- Assemble the status line ---
output=""

# [ProjectName]
output="${output}${COLOR_SEP}[${RESET}${BOLD}${COLOR_PROJECT}${project_name}${RESET}${COLOR_SEP}]${RESET}"

# Branch (only if found)
if [ -n "$git_branch" ]; then
    output="${output} ${COLOR_BRANCH}${git_branch}${RESET}"
fi

# Separator
output="${output} ${COLOR_SEP}|${RESET} "

# Progress bar + percentage
if [ -n "$used_pct" ]; then
    bar=$(build_bar "$used_pct")
    pct_display=$(printf '%.0f' "$used_pct")
    # Format tokens as Xk (thousands)
    tokens_display=""
    if [ -n "$used_tokens" ]; then
        tokens_display=$(echo "$used_tokens" | awk '{printf " (%.0fk)", $1/1000}')
    fi
    output="${output}${COLOR_BAR_FILL}${bar}${RESET} ${ctx_color}${pct_display}%${tokens_display}${RESET}${DIM} ctx${RESET}"
else
    output="${output}${DIM}ctx: -${RESET}"
fi

# --- Append rate limits to the same line (only if available) ---
if [ -n "$rate_5h" ]; then
    rate_5h_display=$(printf '%.0f' "$rate_5h")
    rc=$(echo "$rate_5h" | awk '{if($1>=90) print "red"; else if($1>=70) print "yellow"; else print "green"}')
    case "$rc" in
        red)    rc_color="$COLOR_CTX_RED"    ;;
        yellow) rc_color="$COLOR_CTX_YELLOW" ;;
        *)      rc_color="$COLOR_CTX_GREEN"  ;;
    esac
    # Calculate time remaining until 5h reset
    time_5h=""
    if [ -n "$rate_5h_resets" ]; then
        remaining=$((rate_5h_resets - now_epoch))
        if [ "$remaining" -gt 0 ]; then
            hrs=$((remaining / 3600))
            mins=$(((remaining % 3600) / 60))
            time_5h=" ${hrs}h${mins}m"
        fi
    fi
    output="${output} ${COLOR_SEP}|${RESET} ${DIM}5h:${RESET} ${rc_color}${rate_5h_display}%${RESET}${DIM}${time_5h}${RESET}"
fi
if [ -n "$rate_7d" ]; then
    rate_7d_display=$(printf '%.0f' "$rate_7d")
    rc=$(echo "$rate_7d" | awk '{if($1>=90) print "red"; else if($1>=70) print "yellow"; else print "green"}')
    case "$rc" in
        red)    rc_color="$COLOR_CTX_RED"    ;;
        yellow) rc_color="$COLOR_CTX_YELLOW" ;;
        *)      rc_color="$COLOR_CTX_GREEN"  ;;
    esac
    # Calculate time remaining until 7d reset
    time_7d=""
    if [ -n "$rate_7d_resets" ]; then
        remaining=$((rate_7d_resets - now_epoch))
        if [ "$remaining" -gt 0 ]; then
            days=$((remaining / 86400))
            hrs=$(((remaining % 86400) / 3600))
            mins=$(((remaining % 3600) / 60))
            if [ "$days" -gt 0 ]; then
                time_7d=" ${days}d${hrs}h"
            else
                time_7d=" ${hrs}h${mins}m"
            fi
        fi
    fi
    output="${output} ${COLOR_SEP}|${RESET} ${DIM}7d:${RESET} ${rc_color}${rate_7d_display}%${RESET}${DIM}${time_7d}${RESET}"
fi

printf "%b\n" "$output"
