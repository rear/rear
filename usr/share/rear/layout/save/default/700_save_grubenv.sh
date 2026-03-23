# Save grubenv (GRUB environment block) to $VAR_DIR/recovery/grubenv.
# See https://www.gnu.org/software/grub/manual/grub/html_node/Environment-block.html
# for more details about grubenv.

function list_grubenv() {
    local grub_editenv
    if ! grub_editenv=$(get_grub_editenv); then
        LogPrintError "Failed to list grubenv: neither grub-editenv nor grub2-editenv was found"
        return 1
    fi

    "$grub_editenv" - list
}

# env_block sets the external raw block where GRUB can store environment block.
# See https://www.gnu.org/software/grub/manual/grub/html_node/env_005fblock.html
# for more details about env_block.
function is_fs_envblock_used() {
    list_grubenv | grep -q "^env_block="
}

function save_grubenv() {
    local grubenv_file="$VAR_DIR/recovery/grubenv"

    if ! list_grubenv > "$grubenv_file"; then
        LogPrintError "Failed to save grubenv to '$grubenv_file'"
        return 1
    fi

    Log "grubenv was successfully saved to '$grubenv_file'"
    return 0
}

# Save grubenv only if Btrfs envblock is used, because the envblock
# located in the Btrfs header is not accessible during recovery. In other cases,
# the envblock is located at /boot/grub/envblock or /boot/grub2/envblock,
# which is backed up and restored as a regular file.
if is_grub2_used && is_fs_envblock_used; then
    save_grubenv
fi
