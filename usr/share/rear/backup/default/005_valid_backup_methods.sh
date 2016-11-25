
# Check what BACKUP methods are mentioned in the form BACKUP=method in default.conf
# and error out when a BACKUP method is not found this way in default.conf
# to ensure that the user cannot specify a non-working BACKUP in /etc/rear/local.conf
# and to ensure that each implemented BACKUP method is mentioned in default.conf
# to have a minimum documentation about what BACKUP methods are implemented in ReaR
# see https://github.com/rear/rear/issues/914
# and https://github.com/rear/rear/issues/159

local backup_method
local valid_backup_methods=()

for backup_method in $( grep 'BACKUP=' $SHARE_DIR/conf/default.conf | grep -v '_' | cut -d= -f2 | awk '{print $1}' | sort -u ) ; do
    valid_backup_methods=( ${valid_backup_methods[@]} "$backup_method" )
done

if ! grep -q "$BACKUP" <<< $( echo ${valid_backup_methods[@]} ) ; then
    Error "The BACKUP method '$BACKUP' is not known to ReaR."
fi

