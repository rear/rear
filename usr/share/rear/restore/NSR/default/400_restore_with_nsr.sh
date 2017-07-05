# 400_restore_with_nsr.sh

LogUserOutput "Starting nsrwatch on console 8"
TERM=linux nsrwatch -p 1 -s $(cat $VAR_DIR/recovery/nsr_server ) </dev/tty8 >/dev/tty8 &

LogUserOutput "Restore filesystem $(cat $VAR_DIR/recovery/nsr_paths) with recover"

blank=" "
# Use the original STDOUT when 'rear' was launched by the user for the 'while read ... echo' output
# (which also reads STDERR of the 'recover' command so that 'recover' errors are 'echo'ed to the user)
# but keep STDERR of the 'while' command going to the log file so that 'rear -D' output goes to the log file:
recover -s $(cat $VAR_DIR/recovery/nsr_server) -c $(hostname) -d $TARGET_FS_ROOT -a $(cat $VAR_DIR/recovery/nsr_paths) 2>&1 \
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

