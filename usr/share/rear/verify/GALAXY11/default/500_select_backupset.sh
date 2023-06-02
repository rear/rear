# if no backupset is defined, query the user for it
contains_visible_char "$GALAXY11_BACKUPSET" && return 0

local backupsets
IFS=$'\n' read -r -d "" -a backupsets < <(
	qlist backupset -c $HOSTNAME -a Q_LINUX_FS | sed -E -e 's/ +$//'
)

until IsInArray "$GALAXY11_BACKUPSET" "${backupsets[@]}"; do
	GALAXY11_BACKUPSET=$( UserInput -I GALAXY11_BACKUPSET -D "${backupsets[0]}" -p "Select CommVault backupset to use (ENTER for first one):" "${backupsets[@]}" )
done
