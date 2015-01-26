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

# Use the included_mountpoints array derived from the disklayout.conf to determine the default
# TSM filespaces to include in a restore. 
included_mountpoints=( $(grep ^fs $VAR_DIR/layout/disklayout.conf  | awk '{print $3}') )

# TSM does not restore the mountpoints for filesystems it does not recover. Setting the
# MOUNTPOINTS_TO_RESTORE variable allows this to be recreated in the restore 
# default 90_create_missing_directories.sh script
excluded_mountpoints=( $(grep ^#fs $VAR_DIR/layout/disklayout.conf  | awk '{print $3}') )
MOUNTPOINTS_TO_RESTORE=${excluded_mountpoints[@]#/}

# find out which filespaces (= mountpoints) are available for restore
LC_ALL=${LANG_RECOVER} dsmc query filespace -date=2 -time=1 | grep -A 10000 'File' >$TMP_DIR/tsm_filespaces
# Error code 8 can be ignored, see bug report at
# https://sourceforge.net/tracker/?func=detail&atid=859452&aid=1942895&group_id=171835
[ $PIPESTATUS -eq 0 -o $PIPESTATUS -eq 8 ]
StopIfError "'dsmc query filespace' failed !"
TSM_FILESPACE_TEXT="$(cat $TMP_DIR/tsm_filespaces)"
TSM_FILESPACES=()
TSM_FILESPACE_NUMS=( )
# TSM_FILESPACE_INCLUDED arrays for use as default value for TSM_RESTORE_FILESPACE_NUMS
TSM_FILESPACE_INCLUDED=( )
TSM_FILESPACE_INCLUDED_NUMS=( )
while read num date time type path ; do
	TSM_FILESPACES[$num]="$path"
	TSM_FILESPACE_NUMS[$num]="$num"
        if IsInArray $path "${included_mountpoints[@]}" ; then
              TSM_FILESPACE_INCLUDED[$num]="$path"
              TSM_FILESPACE_INCLUDED_NUMS[$num]="$num"
        fi
done < <(grep -A 10000 '^  1' <<<"$TSM_FILESPACE_TEXT")

Log "Available filespaces:
$TSM_FILESPACE_TEXT"

echo "
The TSM Server reports the following for this node:
$(echo "$TSM_FILESPACE_TEXT" | sed -e 's/^/\t\t/')
Please enter the numbers of the filespaces we should restore.
Pay attention to enter the filesystems in the correct order
(like restore / before /var/log) ! "
read -t $WAIT_SECS -p "(default: ${TSM_FILESPACE_INCLUDED_NUMS[*]}): [$WAIT_SECS secs] " -r TSM_RESTORE_FILESPACE_NUMS 2>&1
if test -z "$TSM_RESTORE_FILESPACE_NUMS" ; then
	TSM_RESTORE_FILESPACE_NUMS="${TSM_FILESPACE_INCLUDED_NUMS[*]}" # set default on ENTER
	Log "User pressed ENTER, setting default of ${TSM_FILESPACE_INCLUDED_NUMS[*]}"
fi
# remove extra spaces
TSM_RESTORE_FILESPACE_NUMS="$(echo "$TSM_RESTORE_FILESPACE_NUMS" |tr -s " ")"

[ "${#TSM_RESTORE_FILESPACE_NUMS}" -gt 0 ]
StopIfError "No filespaces selected !"

LogPrint "We will now restore the following filesystems:"
for num in $TSM_RESTORE_FILESPACE_NUMS ; do
        LogPrint "${TSM_FILESPACES[$num]}"
done
read -t $WAIT_SECS -r -p "Is this selection correct ? (Y|n) [$WAIT_SECS secs] " 2>&1
case "$REPLY" in
	""|y|Y)	Log "User confirmed filespace selection" ;;
	*)	Error "User aborted filespace confirmation." ;;
esac

