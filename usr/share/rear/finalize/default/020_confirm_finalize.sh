#
# In migration mode let the user confirm that
# the up to that point recreated system
# (i.e. recreated disk layout plus restored backup)
# is ready to run the finalize stage
# (i.e. to recreate the initrd and to reinstall the bootloader).
# For example in case of a changed disk layout certain config files
# that were restored from the backup could contain outdated content
# which may need manual adaptions before the initrd gets recreated
# and the bootloader gets reinstalled.
# In particular in case of a changed disk layout the restored etc/fstab
# is usually outdated and needs to be manually adapted to get
# the recreated system ready to run the scripts of the finalize stage.
#

# Skip if not in migration mode:
is_true "$MIGRATION_MODE" || return 0

rear_workflow="rear $WORKFLOW"
restored_fstab="$TARGET_FS_ROOT/etc/fstab"
rear_shell_history="$( echo -e "chroot $TARGET_FS_ROOT\ncd $TARGET_FS_ROOT/etc/\nvi $restored_fstab\nless $restored_fstab" )"
unset choices
choices[0]="Confirm it is OK to recreate initrd and reinstall bootloader and continue '$rear_workflow'"
choices[1]="Edit restored etc/fstab ($restored_fstab)"
choices[2]="View restored etc/fstab ($restored_fstab)"
choices[3]="Use Relax-and-Recover shell and return back to here"
choices[4]="Abort '$rear_workflow'"
prompt="Confirm restored config files or edit them"
choice=""
wilful_input=""
# When USER_INPUT_RESTORED_FILES_CONFIRMATION has any 'true' value be liberal in what you accept and
# assume choices[0] 'Confirm recreate initrd and reinstall bootloader' was actually meant:
is_true "$USER_INPUT_RESTORED_FILES_CONFIRMATION" && USER_INPUT_RESTORED_FILES_CONFIRMATION="${choices[0]}"
while true ; do
    choice="$( UserInput -I RESTORED_FILES_CONFIRMATION -p "$prompt" -D "${choices[0]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"
    case "$choice" in
        (${choices[0]})
            # Confirm restored config files and continue:
            is_true "$wilful_input" && LogPrint "User confirmed restored files" || LogPrint "Continuing '$rear_workflow' by default"
            break
            ;;
        (${choices[1]})
            # Run 'vi' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            vi $restored_fstab 0<&6 1>&7 2>&8
            ;;
        (${choices[2]})
            # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            less $restored_fstab 0<&6 1>&7 2>&8
            ;;
        (${choices[3]})
            # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
            rear_shell "" "$rear_shell_history"
            ;;
        (${choices[4]})
            abort_recreate
            Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}"
            ;;
    esac
done

