#
# here we offer to setup HP RAID controllers according to the information collected during the dr stage
#
#

# skip script if nothing to do
test -d $VAR_DIR/recovery/hpacucli || return 0

for SLOTDIR in $VAR_DIR/recovery/hpacucli/Slot_* ; do

	# little sanity check
	test -s "$SLOTDIR"/config.txt -a -s "$SLOTDIR"/hpacucli-commands.sh ||\
       		Error "config.txt or hpacucli-commands.sh missing from '$SLOTDIR'"
	LogPrint "Found HP RAID controller configuration:"
	LogPrint "$(cat "$SLOTDIR"/config.txt)"
	Print ""
	Print "Do you want to restore this configuration? All logical drives on this controller"
	Print "will be erased and the above configuration restored. The hard disks have to be"
	Print "installed exactly as in the above configuration dump!"
	Print ""
	read 2>&1 -t 60 -p "Type exactly 'Yes' to restore RAID or press Enter to skip [60secs] "
	test "$REPLY" = Yes || continue # require YES

	SLOT="${SLOTDIR##*Slot_}" # remove leading path to extract slot number

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
