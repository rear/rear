#!/bin/bash
# Set up grubenv (GRUB environment block)

function cleanup_grubenv() {
    # It is assumed that grubenv is located at either /boot/grub2/grubenv or /boot/grub/grubenv.
    # If grubenv is a regular file, it is removed. If grubenv is a symlink, the symlink target
    # is removed while the symlink itself is kept, becoming a dangling symlink. grub-editenv
    # follows the symlink and initializes grubenv at the target location.
    local grubenv
    for grubenv in "${GRUBENV_LOCATIONS[@]}"; do
        grubenv="${TARGET_FS_ROOT}${grubenv}"
        if [ -h "$grubenv" ]; then
            local actual_path
            actual_path=$(readlink -e "$grubenv") || return 1
            rm -f "$actual_path"
            return
        elif [ -f "$grubenv" ]; then
            rm -f "$grubenv"
            return
        fi
    done

    return 1
}

function set_grubenv() {
    local grub_editenv
    if ! grub_editenv=$(get_grub_editenv); then
        LogPrintError "Failed to set grubenv: neither grub-editenv nor grub2-editenv was found"
        return 1
    fi

    # It is essential to set up the environment block in the reserved btrfs sector
    # See https://en.opensuse.org/GRUB#GRUB2_on_btrfs_/boot for more details
    run_in_target_fs_root "\"$grub_editenv\" - unset dummy"

    local exit_code=0
    local var_value
    while IFS= read -r var_value; do
        local var="${var_value%=*}"
        # env_block is read-only after initialization
        if [ "$var" = "env_block" ] ; then
            continue
        fi
        if ! run_in_target_fs_root "\"$grub_editenv\" - set \"$var_value\""; then
            LogPrintError "Failed to set '$var_value' to grubenv"
            exit_code=1
        fi
    done < "$GRUBENV_PATH"

    if [ $exit_code -eq 0 ]; then
        Log "grubenv was set successfully"
    fi

    return $exit_code
}

if is_grubenv_set_required; then
    if ! cleanup_grubenv; then
        LogPrintError "Failed to clean up grubenv before setting it"
        return 1
    fi
    set_grubenv
fi
