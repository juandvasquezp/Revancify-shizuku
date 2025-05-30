#!/usr/bin/bash

PKG_NAME="$1"
UNINSTALL_FROM_ALL_USERS="$2"
STORAGE="$3"

if [ -z "$STORAGE" ]; then
    log() { echo "$1"; }
else
    log() { echo "- $1" >> "$STORAGE/rish_log.txt"; }
fi

# Uninstall command
if [ "$UNINSTALL_FROM_ALL_USERS" = true ]; then
    CMD_RISH="pm uninstall --user all $PKG_NAME"
else
    CMD_RISH="pm uninstall --user current $PKG_NAME"
fi

# We execute the uninstall command using rish
OUTPUT=$(rish -c "$CMD_RISH" 2>&1)
log "Uninstall command: $CMD_RISH"
log "Uninstall output: $OUTPUT"

# We check the output for success or failure
if echo "$OUTPUT" | grep -q "^Success"; then
    log "Uninstall succeeded."
    exit 0
else
    log "Uninstall failed."
    exit 1
fi