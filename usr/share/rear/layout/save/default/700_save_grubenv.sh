# Save grubenv (GRUB environment block) to $VAR_DIR/recovery/grubenv.
# See https://www.gnu.org/software/grub/manual/grub/html_node/Environment-block.html
# for more details about grubenv.

function save_grubenv() {
    if ! list_grubenv > "$GRUBENV_PATH"; then
        LogPrintError "Failed to save grubenv to '$GRUBENV_PATH'"
        return 1
    fi

    Log "grubenv was successfully saved to '$GRUBENV_PATH'"
    return 0
}

# Save grubenv only if Btrfs envblock is used, because the envblock
# located in the Btrfs header is not accessible during recovery. In other cases,
# the envblock is located at /boot/grub/grubenv or /boot/grub2/grubenv,
# which is backed up and restored as a regular file.
if is_grubenv_set_required; then
    save_grubenv
fi
