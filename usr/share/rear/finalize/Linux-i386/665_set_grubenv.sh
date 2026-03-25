# Set up grubenv (GRUB environment block)

function set_grubenv() {
    local grubenv_file="$VAR_DIR/recovery/grubenv"

    # A non-existing grubenv_file is considered OK because it exists only
    # if env_block was set.
    if [ ! -f "$grubenv_file" ]; then
        return 0
    fi

    local grub_editenv
    if ! grub_editenv=$(get_grub_editenv); then
        LogPrintError "Failed to set grubenv: neither grub-editenv nor grub2-editenv was found"
        return 1
    fi

    # Remove grubenv from the restored filesystem before setting variables
    local restored_grubenv
    for restored_grubenv in /boot/grub2/grubenv /boot/grub/grubenv; do
        restored_grubenv="${TARGET_FS_ROOT}${restored_grubenv}"
        if [ -f "$restored_grubenv" ]; then
            rm "$restored_grubenv"
            Log "'$restored_grubenv' was removed"
        fi
    done

    # It is essential to set up the environment block in the reserved btrfs sector
    # See https://en.opensuse.org/GRUB#GRUB2_on_btrfs_/boot for more details
    chroot "$TARGET_FS_ROOT" /bin/bash -c "\"$grub_editenv\" - unset dummy"

    local exit_code=0
    local var_value
    while IFS= read -r var_value; do
        local var="${var_value%=*}"
        # env_block is read-only after initialization
        if [ "$var" = "env_block" ] ; then
            continue
        fi
        if ! chroot "$TARGET_FS_ROOT" /bin/bash -c "\"$grub_editenv\" - set \"$var_value\""; then
            LogPrintError "Failed to set '$var_value' to grubenv"
            exit_code=1
        fi
    done < "$grubenv_file"

    if [ $exit_code -eq 0 ]; then
        Log "grubenv was set successfully"
    fi

    return $exit_code
}

if is_grub2_used; then
    set_grubenv
fi
