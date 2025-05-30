#!/usr/bin/bash

PKG_NAME="$1"
APP_NAME="$2"
EXPORTED_APK_NAME="$4"
STORAGE="$3"

if [ -z "$STORAGE" ]; then
    log() { echo "$1"; }
else
    log() { echo "- $1" >> "$STORAGE/rish_log.txt"; }
fi

# Current user, it's usually 0, but can be different in some cases.
CURRENT_USER=$(rish -c 'am get-current-user' 2>/dev/null)

# It's needed for pm install to have the APK in the /data/local/tmp/ directory
PATCHED_APP_PATH="/data/local/tmp/revancify/$PKG_NAME.apk"
EXPORTED_APP_PATH="/storage/emulated/$CURRENT_USER/Revancify/Patched/$EXPORTED_APK_NAME"

# This is almost the same as the mouth.sh script from the su version.
if [ "$(rish -c '[ -d "/data/local/tmp/revancify" ] && echo Exists || echo Missing')" == "Missing" ]; then
    rish -c 'mkdir "/data/local/tmp/revancify"'
    log "/data/local/tmp/revancify created."
fi

# Named the same as the su version, maybe so people can choose to use su or rish, idk.
if [ "$(rish -c '[ -e "'"$PATCHED_APP_PATH"'" ] && echo Exists || echo Missing')" == "Exists" ]; then
    rish -c 'rm "'"$PATCHED_APP_PATH"'"'
    log "Residual $PATCHED_APP_PATH deleted"
fi

log "Copying exported APK to /data/local/tmp/revancify..."
rish -c 'cp -f "'"$EXPORTED_APP_PATH"'" "'"$PATCHED_APP_PATH"'"'

if [ "$(rish -c '[ -e "'"$PATCHED_APP_PATH"'" ] && echo Exists || echo Missing')" == "Missing" ]; then
    log "Failed to move patched APK to $PATCHED_APP_PATH"
    return 1
fi

CMD_RISH="pm install --user current $PATCHED_APP_PATH"

# We execute the install command using rish
OUTPUT=$(rish -c "$CMD_RISH" 2>&1)
log "Install command: $CMD_RISH"
log "Install output: $OUTPUT"

# We check the output for success or failure
if echo "$OUTPUT" | grep -q "^Success"; then
    log "Install succeeded."
    exit 0
else
    log "Install failed."
    exit 1
fi