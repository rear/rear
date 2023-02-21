#
# show the last job that ran

# if no backupset is defined, query the user for it
test "$GALAXY11_BACKUPSET" || return 0

local backupsets
IFS=$'\n' read -r -d "" -a backupsets < <(
	qlist backupset -c $HOSTNAME -a Q_LINUX_FS
)

until IsInArray "$GALAXY11_BACKUPSET" "${backupsets[@]}"; do
	GALAXY11_BACKUPSET=$( UserInput -I GALAXY11_BACKUPSET -p "Select CommVault backupset to use:" "${backupsets[@]}" )
done
