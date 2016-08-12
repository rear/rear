# Stop if no key is configured

if is_false "$BACKUP_PROG_CRYPT_ENABLED" ; then
  return
fi

[ ! -z "$BACKUP_PROG_CRYPT_KEY" ]
StopIfError "Please enter BACKUP_PROG_CRYPT_KEY in $CONFIG_DIR/local.conf !"
