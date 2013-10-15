# 40_restore_with_nsr.sh

LogPrint "Starting nsrwatch on console 8"
TERM=linux nsrwatch -p 1 -s $(cat $VAR_DIR/recovery/nsr_server ) </dev/tty8 >/dev/tty8 &

LogPrint "Restore filesystem $(cat $VAR_DIR/recovery/nsr_paths) with recover"

BLANK=" "
recover -s $(cat $VAR_DIR/recovery/nsr_server) -c $(hostname) -d /mnt/local -a $(cat $VAR_DIR/recovery/nsr_paths) 2>&1 | \
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
done

