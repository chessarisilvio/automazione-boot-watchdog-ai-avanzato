#!/usr/bin/env bash
# notify_telegram.sh - Send a message to Telegram bot
# Usage: notify_telegram.sh "message text"
# Requires environment variables: TOKEN (bot token) and CHAT_ID (target chat ID)

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 \"message text\"" >&2
    exit 1
fi

MESSAGE="$1"

if [ -z "${TOKEN:-}" ]; then
    echo "ERROR: TOKEN environment variable not set" >&2
    exit 1
fi

if [ -z "${CHAT_ID:-}" ]; then
    echo "ERROR: CHAT_ID environment variable not set" >&2
    exit 1
fi

# Telegram API endpoint
URL="https://api.telegram.org/bot${TOKEN}/sendMessage"

# Send message
RESPONSE=$(curl -s -X POST "$URL" \
    -d chat_id="$CHAT_ID" \
    -d text="$MESSAGE" \
    -d parse_mode="HTML" 2>/dev/null) || {
    echo "ERROR: Failed to send message to Telegram" >&2
    exit 1
}

# Check if Telegram API returned ok
if ! echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "ERROR: Telegram API error: $RESPONSE" >&2
    exit 1
fi

exit 0