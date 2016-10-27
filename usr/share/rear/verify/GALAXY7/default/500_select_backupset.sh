#
# show the last job that ran

# if no backupset is defined, query the user for it
if ! test "$GALAXY7_BACKUPSET" ; then
	let c=0 ; while read ; do backupsets[c++]="$REPLY" ; done < <(
		qlist backupset -c $HOSTNAME -a Q_LINUX_FS
	)

	LogPrint "
Found the following backupsets:
$(
		for ((d=0 ; d<c ; d++)) ; do
			echo "     [$d] ${backupsets[d]}"
		done
	)"

	read -p "Please select the backupset to use: " answer 2>&1
	test $answer -ge 0 -a $answer -lt $c ||\
		Error "You must specify the backupset with its number."

	GALAXY7_BACKUPSET="${backupsets[answer]}"
fi
