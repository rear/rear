#
# here we offer to setup HP RAID controllers according to the information collected during the dr stage
#
#

# Only run this if not in layout mode.
if [ -n "$USE_LAYOUT" ] ; then
    return 0
fi

# only run script if cciss driver is loaded
test -d $VAR_DIR/recovery/hpacucli && grep -q cciss < <(lsmod) ||return 0

for SLOTDIR in $VAR_DIR/recovery/hpacucli/Slot_* ; do

	SLOT="${SLOTDIR##*Slot_}" # remove leading path to extract slot number

	# little sanity check
	if ! [ -s "$SLOTDIR"/config.txt -a -s "$SLOTDIR"/hpacucli-commands.sh ] ; then
		LogPrint "Error reading controller configuration:"
		LogPrint "config.txt or hpacucli-commands.sh missing from '$SLOTDIR'"
		read 2>&1 -p "Please configure controller $SLOT manually and press any key..."
		continue
	fi

	LogPrint "Found HP RAID controller configuration:"
	LogPrint "$(cat "$SLOTDIR"/config.txt)"
	Print ""
	Print "Do you want to restore this configuration? All logical drives on this controller"
	Print "will be erased and the above configuration restored. The hard disks have to be"
	Print "installed exactly as in the above configuration dump!"
	Print ""
	read 2>&1 -t 60 -p "Type exactly 'Yes' to restore RAID or press Enter to skip [60secs] "
	test "$REPLY" = Yes || continue # require YES

	# prepare list of commands to run
	command_list="hpacucli ctrl slot=$SLOT delete forced
$(cat "$SLOTDIR"/hpacucli-commands.sh)"

	Log "$command_list"
	# run each command from the list and report on the success
	while read ; do
		Log "Running '$REPLY'"
		eval "$REPLY" || Error "Command failed with $?"
	done <<<"$command_list"

	ProgressStart "Configuration restored successfully, reloading CCISS driver..."
	sleep 1 ; ProgressStep ; sleep 1
	rmmod cciss
	sleep 1 ; ProgressStep ; sleep 1
	modprobe cciss
	sleep 1 ; ProgressStep ; sleep 1
	ProgressStop
	
done # for SLOTDIR
