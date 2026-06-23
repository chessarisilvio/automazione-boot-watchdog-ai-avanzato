#!/usr/bin/env bash
# watchdog.sh - Basic watchdog for llama-stack service
# Checks: process existence, VRAM usage, token-per-second from metrics log
# Returns 0 if all OK, 1 otherwise

# Configuration via environment variables (see .env.example)
LLAMA_PROCESS="${LLAMA_PROCESS:-llama-stack}"
METRICS_LOG="${METRICS_LOG:-/var/log/llama-stack/metrics.log}"
# VRAM threshold ratio (used/total) above which we consider unhealthy
VRAM_THRESHOLD="${VRAM_THRESHOLD:-0.95}"
# Minimum token-per-second to consider healthy
MIN_TOK_PER_SEC="${MIN_TOK_PER_SEC:-1.0}"

# 1) Check process existence
if ! pidof "$LLAMA_PROCESS" > /dev/null 2>&1; then
    echo "ERROR: Process '$LLAMA_PROCESS' not found"
    exit 1
fi

# 2) Check VRAM usage
# Run nvidia-smi and parse output: used,total
if ! command -v nvidia-smi > /dev/null 2>&1; then
    echo "ERROR: nvidia-smi not found"
    exit 1
fi
VRAM_OUTPUT=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to run nvidia-smi"
    exit 1
fi
# Parse used and total (first line, assuming single GPU)
IFS=',' read -r vram_used vram_total <<< "$VRAM_OUTPUT"
# Remove possible whitespace
vram_used=$(echo "$vram_used" | xargs)
vram_total=$(echo "$vram_total" | xargs)
if [ -z "$vram_used" ] || [ -z "$vram_total" ] || [ "$vram_total" -eq 0 ]; then
    echo "ERROR: Invalid VRAM output: used='$vram_used' total='$vram_total'"
    exit 1
fi
# Calculate ratio
vram_ratio=$(awk "BEGIN {printf \"%.2f\", $vram_used/$vram_total}")
# Check if ratio exceeds threshold
if (( $(echo "$vram_ratio > $VRAM_THRESHOLD" | bc -l) )); then
    echo "ERROR: VRAM usage too high: $vram_ratio (threshold $VRAM_THRESHOLD)"
    exit 1
fi

# 3) Check token-per-second from metrics log
if [ ! -f "$METRICS_LOG" ]; then
    echo "ERROR: Metrics log not found: $METRICS_LOG"
    exit 1
fi
# Get the last line that contains a token-per-second metric.
# Assuming format like: token_per_second=12.34
tok_per_sec=$(grep -o 'token_per_second=[0-9]*\.[0-9]*' "$METRICS_LOG" | tail -1 | cut -d'=' -f2)
if [ -z "$tok_per_sec" ]; then
    # fallback: maybe just a number
    tok_per_sec=$(tail -1 "$METRICS_LOG" | grep -o '[0-9]*\.[0-9]*' | tail -1)
fi
if [ -z "$tok_per_sec" ]; then
    echo "ERROR: Could not extract token-per-second from metrics log"
    exit 1
fi
# Check if token-per-second meets minimum
if (( $(echo "$tok_per_sec < $MIN_TOK_PER_SEC" | bc -l) )); then
    echo "ERROR: Token-per-second too low: $tok_per_sec (minimum $MIN_TOK_PER_SEC)"
    exit 1
fi

# All checks passed
echo "OK: Process running, VRAM usage $vram_ratio, token-per-second $tok_per_sec"
exit 0