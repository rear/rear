# 400_restore_with_nsr.sh

LogUserOutput "Starting nsrwatch on console 8"
TERM=linux nsrwatch -p 1 -s $(cat $VAR_DIR/recovery/nsr_server ) </dev/tty8 >/dev/tty8 &

LogUserOutput "Restore filesystem $(cat $VAR_DIR/recovery/nsr_paths) with recover"

BLANK=" "
# Use the original STDOUT and STDERR when 'rear' was launched by the user for the 'while read ... echo' output:
recover -s $(cat $VAR_DIR/recovery/nsr_server) -c $(hostname) -d $TARGET_FS_ROOT -a $(cat $VAR_DIR/recovery/nsr_paths) 2>&1 | \
while read -r ; do
    echo -ne "\r${BLANK:1-COLUMNS}\r"
    case "$REPLY" in
        *:*\ *)	echo "$REPLY" ;;
        ./*)	if [ "${#REPLY}" -ge $((COLUMNS-5)) ] ; then
                    echo -n "... ${REPLY:5-COLUMNS}"
                else
                    echo -n "$REPLY"
                fi
                ;;
        *)	echo "$REPLY" ;;
    esac
done 1>&7 2>&8

