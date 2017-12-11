#
# Read TSM vars from TSM config files ( look a bit like an init file with KEY=VALUE pairs )
# The keys are loaded into environment variables called TSM_SYS_$KEY
# Since TSM has several options that have a dot in their name, the dot is replaced by an underscore.
# Read dsm.sys:
while read KEY VALUE ; do
    echo "$KEY" | grep -q '*' && continue
    test -z "$KEY" && continue
    KEY="$(echo "$KEY" | tr a-z. A-Z_)"
    export TSM_SYS_$KEY="${VALUE//\"}"
done </opt/tivoli/tsm/client/ba/bin/dsm.sys
# Read dsm.opt:
while read KEY VALUE ; do
    echo "$KEY" | grep -q '*' && continue
    test -z "$KEY" && continue
    KEY="$(echo "$KEY" | tr a-z. A-Z_)"
    export TSM_OPT_$KEY="${VALUE//\"}"
done </opt/tivoli/tsm/client/ba/bin/dsm.opt

# Check that TSM server is set in dsm.sys:
test "$TSM_SYS_TCPSERVERADDRESS" || Error "TSM Server not set in dsm.sys (TCPSERVERADDRESS)"

# Check that TSM server is actually available (ping):
if test "$PING" ; then
    ping -c 1 "$TSM_SYS_TCPSERVERADDRESS" >/dev/null 2>&1 || Error "TSM server '$TSM_SYS_TCPSERVERADDRESS' does not respond to a 'ping'"
    Log "TSM server '$TSM_SYS_TCPSERVERADDRESS' seems to be up and running (responds to a 'ping')"
else
    Log "Skipping ping test for TSM server '$TSM_SYS_TCPSERVERADDRESS'"
fi

# Use the included_mountpoints array derived from the disklayout.conf to determine the default TSM filespaces
# to include in a restore (all filesystems plus all mounted btrfs subvolumes except SUSE snapshot subvolumes):
included_mountpoints=( $( grep '^fs' $VAR_DIR/layout/disklayout.conf | awk '{print $3}' ) )
included_mountpoints=( "${included_mountpoints[@]}" $( grep '^btrfsmountedsubvol' $VAR_DIR/layout/disklayout.conf | awk '{print $3}' | grep -v '/.snapshots' ) )
included_mountpoints=( $( tr ' ' '\n' <<<"${included_mountpoints[@]}" | awk '!u[$0]++' | tr '\n' ' ' ) )

# TSM does not restore the mountpoints for filesystems it does not recover.
# Appending excluded mountpoint directories to the DIRECTORY_ENTRIES_TO_RECOVER array
# (there could be already user specified directories in the DIRECTORY_ENTRIES_TO_RECOVER array)
# allows them to be recreated in the restore default 900_create_missing_directories.sh script:
excluded_mountpoints=( $( grep '^#fs' $VAR_DIR/layout/disklayout.conf | awk '{print $3}' ) )
DIRECTORY_ENTRIES_TO_RECOVER=( "${DIRECTORY_ENTRIES_TO_RECOVER[@]}" "${excluded_mountpoints[@]}" )

# Find out which filespaces (= mountpoints) are available for restore.
# Error code 8 can be ignored, see bug report at
# https://sourceforge.net/tracker/?func=detail&atid=859452&aid=1942895&group_id=171835
LC_ALL=${LANG_RECOVER} dsmc query filespace -date=2 -time=1 -scrollprompt=no | grep -A 10000 'File' >$TMP_DIR/tsm_filespaces
[ $PIPESTATUS -eq 0 -o $PIPESTATUS -eq 8 ] || Error "'dsmc query filespace' failed"

TSM_FILESPACE_TEXT="$( cat $TMP_DIR/tsm_filespaces )"
TSM_FILESPACES=()
TSM_FILESPACE_NUMS=( )
# TSM_FILESPACE_INCLUDED arrays for use as default value for TSM_RESTORE_FILESPACE_NUMS
TSM_FILESPACE_INCLUDED=( )
TSM_FILESPACE_INCLUDED_NUMS=( )
while read num path ; do
    TSM_FILESPACES[$num]="$path"
    TSM_FILESPACE_NUMS[$num]="$num"
    if IsInArray $path "${included_mountpoints[@]}" ; then
        TSM_FILESPACE_INCLUDED[$num]="$path"
        TSM_FILESPACE_INCLUDED_NUMS[$num]="$num"
    fi
done < <((grep -A 10000 '^  1' | awk '{print $1 " " $NF}') <<<"$TSM_FILESPACE_TEXT")

Log "Available filespaces:
$TSM_FILESPACE_TEXT"

LogUserOutput "
The TSM Server reports the following for this node:
$( echo "$TSM_FILESPACE_TEXT" | sed -e 's/^/\t\t/' )
Please enter the numbers of the filespaces we should restore.
Pay attention to enter the filesystems in the correct order
(like restore / before /var/log)"
# Use the original STDIN STDOUT and STDERR when rear was launched by the user
# to get input from the user and to show output to the user (cf. _input-output-functions.sh):
read -t $WAIT_SECS -p "(default: ${TSM_FILESPACE_INCLUDED_NUMS[*]}): [$WAIT_SECS secs] " -r TSM_RESTORE_FILESPACE_NUMS 0<&6 1>&7 2>&8
if test -z "$TSM_RESTORE_FILESPACE_NUMS" ; then
    # Set default on ENTER:
    TSM_RESTORE_FILESPACE_NUMS="${TSM_FILESPACE_INCLUDED_NUMS[*]}"
    Log "User pressed ENTER, setting default of ${TSM_FILESPACE_INCLUDED_NUMS[*]}"
fi
# Remove extra spaces:
TSM_RESTORE_FILESPACE_NUMS="$( echo "$TSM_RESTORE_FILESPACE_NUMS" | tr -s ' ' )"

test "${#TSM_RESTORE_FILESPACE_NUMS}" -gt 0 || Error "No filespaces selected"

LogPrint "The following filesystems will be restored:"
for num in $TSM_RESTORE_FILESPACE_NUMS ; do
    LogPrint "${TSM_FILESPACES[$num]}"
done
# Use the original STDIN STDOUT and STDERR when rear was launched by the user
# to get input from the user and to show output to the user (cf. _input-output-functions.sh):
read -t $WAIT_SECS -r -p "Is this selection correct ? (Y|n) [$WAIT_SECS secs] " 0<&6 1>&7 2>&8
case "$REPLY" in
    (""|y|Y)
        Log "User confirmed filespace selection"
        ;;
    (*)
        Error "User aborted filespace confirmation"
        ;;
esac
