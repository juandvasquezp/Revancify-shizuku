#!/system/bin/sh

# This code is essentially the /root/mount.sh script, but adapted to run in a rish environment.

PKG_NAME="$1"
APP_NAME="$2"
APP_VER="$3"
SOURCE="$4"
DOWNGRADE="$5"

log() {
    echo "- $1" >> "/storage/emulated/0/Revancify/mount_log.txt"
}

rm "/storage/emulated/0/Revancify/mount_log.txt"

log "START"

# Since rish returns 0 on rish success and not the command itself, we use echo to return a custom message and we check on that instead.
if [ "$(rish -c '[ -d "/data/local/tmp/revancify" ] && echo Exists || echo Missing')" = "Missing" ]; then
    rish -c 'mkdir -p "/data/local/tmp/revancify"'
    log "/data/local/tmp/revancify created."
fi

if [ "$(rish -c '[ -e "/data/local/tmp/revancify/'"$PKG_NAME"'.apk" ] && echo Exists || echo Missing')" = "Exists" ]; then
    rish -c 'rm "/data/local/tmp/revancify/'"$PKG_NAME"'.apk"'
    echo "$PKG_NAME.apk deleted"
fi

log "Checking if $APP_NAME $APP_VER is installed"
if [ "$(rish -c 'pm list packages --user 0 | grep -q "'"$PKG_NAME"'" && echo OK')" = "OK" ]; then
  log "$APP_NAME is installed, checking signature..."
  STOCK_APP_PATH=$(rish -c 'pm path "'"$PKG_NAME"'" | sed -n "/base/s/package://p"')
  STOCK_APP_SIGNATURE=$(keytool -printcert -jarfile "$STOCK_APP_PATH" | awk '/SHA256:/{print $2}' | tr -d ':')

  if [ -e "apps/$APP_NAME/$APP_VER-$SOURCE.apk" ]; then
    PATCHED_APP_PATH="apps/$APP_NAME/$APP_VER-$SOURCE.apk"
    PATCHED_APP_SIGNATURE=$(keytool -printcert -jarfile "$PATCHED_APP_PATH" | awk '/SHA256:/{print $2}' | tr -d ':')


    if [ "$STOCK_APP_SIGNATURE" != "$PATCHED_APP_SIGNATURE" ]; then
      log "Signature mismatch: Stock APK signature is $STOCK_APP_SIGNATURE, Patched APK signature is $PATCHED_APP_SIGNATURE"
      log "We need to uninstall the Stock APP."
      UNINSTALL_STOCK=true
    else
      log "Signature match, we will upgrade the app."
    fi
  fi
else
  log "$APP_NAME is NOT installed !!"
fi

if [ "$UNINSTALL_STOCK" = true ]; then
  log "Uninstalling stock $APP_NAME..."
  # We try to maintain the user data, so we use the -k flag.
  rish -c 'pm uninstall --user 0 -k "'"$PKG_NAME"'"'
  log "$APP_NAME uninstalled."
fi

PATCHED_APP_PATH="/data/local/tmp/revancify/$PKG_NAME.apk"

log "Installing $APP_NAME $APP_VER..."
if [ -e "apps/$APP_NAME/$APP_VER-$SOURCE.apk" ]; then
    rish -c 'cp -f "'"apps/$APP_NAME/$APP_VER-$SOURCE.apk"'" "'"$PATCHED_APP_PATH"'"'
    log "Copied patched APK to $PATCHED_APP_PATH."
    if [ ! -e "$PATCHED_APP_PATH" ]; then
      log "Path: $PATCHED_APP_PATH does not exist !!"
      log "Exit !!"
      exit 1
    fi
    
    if [ "$DOWNGRADE" = "on" ]; then
      rish -v -c 'pm install --user 0 -r -d "'"$PATCHED_APP_PATH"'"'
    else
      rish -v -c 'pm install --user 0 -r "'"$PATCHED_APP_PATH"'"'
    fi
    log "$APP_NAME $APP_VER installed."

    # I delete it to clear storage space.
    log "Deleting patched APK from $PATCHED_APP_PATH."
    rish -c 'rm "'"$PATCHED_APP_PATH"'"'
fi

if [ "$(rish -c 'pm list packages --user 0 | grep -q "'"$PKG_NAME"'" && echo OK')" != "OK" ]; then
  log "$APP_NAME $APP_VER installation failed !!"
  log "Exit !!"
  exit 1
fi

log "Installed $APP_NAME $APP_VER successfully."
exit 0