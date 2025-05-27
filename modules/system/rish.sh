#!/usr/bin/bash

installAppRish() {
    notify info "Please Wait !!\nInstalling $APP_NAME..."
    if bash rish/install_rish.sh "$PKG_NAME" "$APP_NAME" "$APP_VER" "$SOURCE" "$ALLOW_APP_VERSION_DOWNGRADE" &> /dev/null; then
        notify msg "$APP_NAME Mounted Successfully using Rish!!"
    else
        notify msg "Installation Failed using Rish !!\nShare logs to developer."
        termux-open --send "$STORAGE/mount_log.txt"
        return 0
    fi
    if [ "$LAUNCH_APP_AFTER_MOUNT" == "on" ]; then
        # The su version used kill -9, I replaced it with the adb command 'am force-stop' avaliable in rish
        rish -c 'settings list secure | sed -n -e "s/\/.*//" -e "s/default_input_method=//p" | xargs am force-stop && pm resolve-activity --brief '"$PKG_NAME"' | tail -n 1 | xargs am start -n && am force-stop com.termux'
    fi
}