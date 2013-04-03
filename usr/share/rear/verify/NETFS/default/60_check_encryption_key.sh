# Stop if no key is configured

if [ $BACKUP_PROG_CRYPT_ENABLED -ne 1 ]; then
  return
fi

[ ! -z "$BACKUP_PROG_CRYPT_KEY" ]
StopIfError "Please enter BACKUP_PROG_CRYPT_KEY in $CONFIG_DIR/local.conf !"
