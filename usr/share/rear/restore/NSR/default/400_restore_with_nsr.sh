# 400_restore_with_nsr.sh
#
# The variable NSR_HAS_PROMPT has been set in
# usr/share/rear/restore/NSR/default/390_request_point_in_time_restore_parameters.sh
# in case NSR_CLIENT_MODE=YES and NSR_CLIENT_REQUEST_RESTORE=YES or unset.
# Only these combinations lead to a prompt (see under "BACKUP=NSR" in default.conf for explanation)

if is_true "$NSR_HAS_PROMPT" then
    LogPrint "Please let the restore process start on Your backup server i.e. $(cat $VAR_DIR/recovery/nsr_server)."
    LogPrint "Make sure all required data is restored to $TARGET_FS_ROOT ."
    LogPrint ""
    LogPrint "When the restore is finished type 'exit' to continue the recovery."
    LogPrint "Info: You can check the recovery process i.e. with the command 'df'."
    LogPrint ""

    rear_shell "Has the restore been completed and are You ready to continue the recovery?"
else
    LogUserOutput "Starting nsrwatch on console 8"
    TERM=linux nsrwatch -p 1 -s $(cat $VAR_DIR/recovery/nsr_server) </dev/tty8 >/dev/tty8 &

    LogUserOutput "Restore filesystem $(cat $VAR_DIR/recovery/nsr_paths) with recover"

    # If a point-in-time recovery requested use this date/time as recover argument
    # else leave it empty
    if [ ${#NSR_ENDTIME[@]} -gt 0 ] ; then
        recover_date="${NSR_ENDTIME[@]}"
        recover_args="-t ${recover_date}"
        LogUserOutput "The recovery date/time is set to ${recover_date} ."
    else
        recover_args=""
        LogUserOutput "The most recent recovery date/time will be used."
    fi

    blank=" "
    # Use the original STDOUT when 'rear' was launched by the user for the 'while read ... echo' output
    # (which also reads STDERR of the 'recover' command so that 'recover' errors are 'echo'ed to the user)
    # but keep STDERR of the 'while' command going to the log file so that 'rear -D' output goes to the log file:
    recover -s $(cat $VAR_DIR/recovery/nsr_server) -c $(hostname) -d $TARGET_FS_ROOT -a $(cat $VAR_DIR/recovery/nsr_paths) $recover_args 2>&1 \
      | while read -r ; do
            echo -ne "\r${blank:1-COLUMNS}\r"
            case "$REPLY" in
                *:*\ *)
                    echo "$REPLY"
                    ;;
                ./*)
                    if [ "${#REPLY}" -ge $((COLUMNS-5)) ] ; then
                        echo -n "... ${REPLY:5-COLUMNS}"
                    else
                        echo -n "$REPLY"
                    fi
                    ;;
                *)
                    echo "$REPLY"
                    ;;
            esac
        done 1>&7
fi
