
# For "rear mkbackup" and also for "rear mkrescue"
# ( also the latter because for most external backup methods only "rear mkrescue"
#   is used because most external backup methods do not implement making a backup
#   but only implement to restore a backup see 'BACKUP SOFTWARE INTEGRATION' in "man rear" )
# check that the BACKUP method implements a matching backup restore method
# i.e. check that a usr/share/rear/restore/$BACKUP directory exists
# and error out when a BACKUP method seems to not support a backup restore
# to ensure that the user cannot specify a non-working BACKUP in /etc/rear/local.conf
# see https://github.com/rear/rear/issues/914
# and https://github.com/rear/rear/issues/159
# and https://github.com/rear/rear/issues/2337#issuecomment-596471615

if ! test -d "$SHARE_DIR/restore/$BACKUP" ; then
    Error "The BACKUP method '$BACKUP' is not supported (no $SHARE_DIR/restore/$BACKUP directory)"
fi

