#
#
# NOTE: In this script we use '"${TSM_FILESPACE_NUMS[*]}"' (instead of [@]) and it seems to be intentionally
# usually this is a cause for trouble but apparently here it was done on purpose.
# If this code doesn't work then please try with [@] instead
#
# 2009-10-12 Schlomo as part of a code review to fix all occurences of [*]
#
#
# read TSM vars from TSM config files
# read dsm.sys
while read KEY VALUE ; do echo "$KEY" | grep -q '*' && continue ; test -z "$KEY" && continue ; KEY="$(echo "$KEY" | tr a-z A-Z)" ; export TSM_SYS_$KEY="${VALUE//\"}" ; done </opt/tivoli/tsm/client/ba/bin/dsm.sys
# read dsm.opt
while read KEY VALUE ; do echo "$KEY" | grep -q '*' && continue ; test -z "$KEY" && continue ; KEY="$(echo "$KEY" | tr a-z A-Z)" ; export TSM_OPT_$KEY="${VALUE//\"}" ; done </opt/tivoli/tsm/client/ba/bin/dsm.opt

# check that TSM server is actually available (ping)
[ "${TSM_SYS_TCPSERVERADDRESS}" ]
StopIfError "TSM Server not set in dsm.sys (TCPSERVERADDRESS) !"

if test "$PING" ; then
	ping -c 1 "${TSM_SYS_TCPSERVERADDRESS}" >&8 2>&1
	StopIfError "Sorry, but cannot reach TSM Server ${TSM_SYS_TCPSERVERADDRESS}"

	Log "TSM Server ${TSM_SYS_TCPSERVERADDRESS} seems to be up and running."
else
	Log "Skipping ping test"
fi


# find out which filespaces (= mountpoints) are available for restore
dsmc query filespace -date=2 -time=1 | grep -A 10000 'File' >$TMP_DIR/tsm_filespaces
# Error code 8 can be ignored, see bug report at
# https://sourceforge.net/tracker/?func=detail&atid=859452&aid=1942895&group_id=171835
[ $PIPESTATUS -eq 0 -o $PIPESTATUS -eq 8 ]
StopIfError "'dsmc query filespace' failed !"
TSM_FILESPACE_TEXT="$(cat $TMP_DIR/tsm_filespaces)"
TSM_FILESPACES=()
TSM_FILESPACE_NUMS=( )
while read num date time type path ; do
	TSM_FILESPACES[$num]="$path"
	TSM_FILESPACE_NUMS[$num]="$num"
done < <(grep -A 10000 '^  1' <<<"$TSM_FILESPACE_TEXT")

Log "Available filespaces:
$TSM_FILESPACE_TEXT"

echo "
The TSM Server reports the following for this node:
$(echo "$TSM_FILESPACE_TEXT" | sed -e 's/^/\t\t/')
Please enter the numbers of the filespaces we should restore.
Pay attention to enter the filesystems in the correct order
(like restore / before /var/log) ! "
read -t 30 -p "(default: ${TSM_FILESPACE_NUMS[*]}): [30sec] " -r TSM_RESTORE_FILESPACE_NUMS 2>&1
if test -z "$TSM_RESTORE_FILESPACE_NUMS" ; then
	TSM_RESTORE_FILESPACE_NUMS="${TSM_FILESPACE_NUMS[*]}" # set default on ENTER
	Log "User pressed ENTER, setting default of ${TSM_FILESPACE_NUMS[*]}"
fi
# remove extra spaces
TSM_RESTORE_FILESPACE_NUMS="$(echo "$TSM_RESTORE_FILESPACE_NUMS" |tr -s " ")"

[ "${#TSM_RESTORE_FILESPACE_NUMS}" -gt 0 ]
StopIfError "No filespaces selected !"

LogPrint "We will now restore the following filesystems:"
for num in $TSM_RESTORE_FILESPACE_NUMS ; do
        LogPrint "${TSM_FILESPACES[$num]}"
done
read -t 30 -r -p "Is this selection correct ? (Y|n) [30sec] " 2>&1
case "$REPLY" in
	""|y|Y)	Log "User confirmed filespace selection" ;;
	*)	Error "User aborted filespace confirmation." ;;
esac

