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

	# Use the original STDIN STDOUT and STDERR when rear was launched by the user
	# to get input from the user and to show output to the user (cf. _framework-setup-and-functions.sh):
	read -p "Please select the backupset to use: " answer 0<&6 1>&7 2>&8
	test $answer -ge 0 -a $answer -lt $c ||\
		Error "You must specify the backupset with its number."

	GALAXY7_BACKUPSET="${backupsets[answer]}"
fi
