#!/usr/bin/bash

installAppRish() {
    log() {
        echo "- $1" >> "$STORAGE/mount_log.txt"
    }
    rm "$STORAGE/mount_log.txt"
    log "START"

    local HIDDEN_APP_INSTALL=false
    local ABLE_TO_INSTALL=true
    local UNINSTALL_CURRENT_INSTALLATION=false
    local UNINSTALL_ALL_USERS=false

    # Case 1: App is installed in a different user with a different signature, we need to uninstall the app from all users (if the system allows it)
    # Case 2: App is installed in the current user with a different signature, we need to uninstall the app from all users or just the current user (if the system doesn't allow uninstalling from all users)
    # Case 3: We're installing a downgrade, no matter the signature, we need to uninstall the current app first, from current user TODO
    # Case 4: Clean install, no app installed, we can proceed with the installation

    # Case 1 is literally the worst, and there's even cases where we cannot know if there's a hidden installation or not, so we need to ask the user if they want to uninstall the app from all users

    notify info "Please Wait !!\nInstalling $APP_NAME using Rish..."
    # Copy the patched APK to the storage
    CANONICAL_VER=${APP_VER//:/}
    cp -f "apps/$APP_NAME/$APP_VER-$SOURCE.apk" "$STORAGE/Patched/$APP_NAME-$CANONICAL_VER-$SOURCE.apk" &> /dev/null
    
    # Verify current installed version and signatures
    log "Checking if $PKG_NAME is installed"
    getInstalledVersion
    if [ "$INSTALLED_VERSION" != "" ]; then
        log "Installed version of $APP_NAME is $INSTALLED_VERSION"
        log "Verifying signatures..."
        local STOCK_APP_PATH
        if [ "$(rish -c 'pm list packages --user current | grep -q "'"$PKG_NAME"'" && echo Installed')" == "Installed" ]; then
            STOCK_APP_PATH=$(rish -c 'pm path --user current "'"$PKG_NAME"'" | sed -n "/base/s/package://p"')
        else
            # If the app is not installed in the current user, we try to get the stock app path from dumpsys
            # This means the app is installed in a different user
            STOCK_APP_PATH=$(rish -c 'dumpsys package com.spotify.music | sed -n "s/^[[:space:]]*path: \(.*base\.apk\)/\1/p"')
            log "Dumpsys used to get stock app path, that means the app is installed but in a different user."
            HIDDEN_APP_INSTALL=true
        fi
        local STOCK_APP_SIGNATURE=$(keytool -printcert -jarfile "$STOCK_APP_PATH" 2>/dev/null | awk '/SHA256:/{print $2}' | tr -d ':')
        local PATCHED_APP_SIGNATURE=$(keytool -printcert -jarfile "apps/$APP_NAME/$APP_VER-$SOURCE.apk" 2>/dev/null | awk '/SHA256:/{print $2}' | tr -d ':')
        if [ "$STOCK_APP_SIGNATURE" != "$PATCHED_APP_SIGNATURE" ]; then
            log "Signature mismatch: We need to uninstall the current APP."
            if [ "$HIDDEN_APP_INSTALL" == true ]; then
                # Case 1: App is installed in a different user with a different signature
                # We cannot proceed with the installation or uninstallation, the user must uninstall the app from the other user first
                # We can try to uninstall the app from all users, but we cannot guarantee it will succeed
                log "Case 1: App installed in a different user with a different signature, we cannot proceed with the installation. Please uninstall the app from that user first."
                dialog --backtitle 'Revancify' --defaultno \
                    --yesno "App is installed in a different user with a different signature.\n\nDo you want to uninstall the app from all users and proceed?\nWe cannot guarantee this will succeed..." 12 45
                if [ $? -eq 0 ]; then
                    # User accepted to uninstall the app from all users for Case 1
                    log "Case 1: User accepted to uninstall the app from all users."
                    UNINSTALL_CURRENT_INSTALLATION=true
                    UNINSTALL_ALL_USERS=true
                else
                    # User declined to uninstall the app from all users for Case 1
                    log "Case 1: User declined to uninstall the app from all users."
                    notify msg "User declined to uninstall the current app.\n\nAborting installation...\n\nCopied patched $APP_NAME apk to Internal Storage..."
                    # TODO: This should end the installation process, but we need to return a value to the caller
                    ABLE_TO_INSTALL=false
                fi
            fi
            # Case 2: App is installed in the current user with a different signature, we can uninstall it and proceed with the installation
            # We use a dialog to ask the user if they want to uninstall the current app
            dialog --backtitle 'Revancify' --defaultno \
                --yesno "The current app has a different signature than the patched one.\n\nDo you want to uninstall the current app and proceed?\n\nThis will uninstall the app in all users" 12 45
            if [ $? -eq 0 ]; then
                # User accepted to uninstall the current app for Case 2
                # We still need to uninstall the app from all users if the systems allows it, otherwise we'll get a signature mismatch error during installation
                log "Case 2: User accepted to uninstall the current app."
                UNINSTALL_CURRENT_INSTALLATION=true
                UNINSTALL_ALL_USERS=true
            fi
            # User declined to uninstall the current app for Case 2
            log "Case 2: User declined to uninstall the current app."
            notify msg "User declined to uninstall the current app.\n\nAborting installation...\n\nCopied patched $APP_NAME apk to Internal Storage..."
            ABLE_TO_INSTALL=false
            # TODO: This should end the installation process, but we need to return a value to the caller
        else
            log "Signature match, we can upgrade the app."
        fi
    else
        log "No installed version found for $APP_NAME found, proceeding with installation."
    fi

    # Check if we're already due for uninstallation
    if [ "$UNINSTALL_CURRENT_INSTALLATION" = false ]; then
        log "Checking if it's a downgrade..."
        if jq -e '.[0] > .[1]' <<< "[\"${INSTALLED_VERSION:-0}\", \"$APP_VER\"]" &> /dev/null; then
            log "Case 3: Installed version $INSTALLED_VERSION is greater than the new version $APP_VER, we are downgrading."
            if [ "$ALLOW_APP_VERSION_DOWNGRADE" == "on" ]; then
                log "Case 3: Downgrades are allowed, asking user for permission to uninstall the current app."
                
                dialog --backtitle 'Revancify' --defaultno \
                    --yesno "The current app version $INSTALLED_VERSION is greater than the new version $APP_VER.\n\nDo you want to uninstall the current version and proceed with the downgrade?" 12 45

                if [ $? -eq 0 ]; then
                    log "Case 3: User agreed to uninstall for clean reinstall."
                    UNINSTALL_CURRENT_INSTALLATION=true
                    #TODO: Do we need to uninstall from all users?
                else
                    log "Case 3: User decided not to uninstall to continue the downgrade. Aborting..."
                    notify msg "User declined to uninstall the current version.\n\nAborting installation...\n\nCopied patched $APP_NAME apk to Internal Storage..."
                    ABLE_TO_INSTALL=false
                    #TODO: This should end the installation process, but we need to return a value to the caller
                fi
            else
                log "Case 3: Downgrades are not allowed, exiting."
                notify msg "Downgrades are not allowed in Configuration, exiting."
                # TODO:
                ABLE_TO_INSTALL=false
            fi
        else
            log "Case 4: No version conflict detected or signatures, proceeding with installation."
        fi
    fi

    if [ "$UNINSTALL_CURRENT_INSTALLATION" = true ]; then
        ABLE_TO_INSTALL=false
        log "Uninstalling current installation of $APP_NAME..."
        if [ "$UNINSTALL_ALL_USERS" = true ]; then
            log "Uninstalling from all users..."
            rish -c "pm uninstall --user all $PKG_NAME" &> /dev/null
        else
            log "Uninstalling from current user only..."
            rish -c "pm uninstall $PKG_NAME" &> /dev/null
        fi
    fi

}