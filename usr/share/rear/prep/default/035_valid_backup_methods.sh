
# Check whether the BACKUP variable specifies a valid backup method.

if [[ ! -d "$SHARE_DIR/backup/$BACKUP" ]]; then
    Error "The BACKUP method '$BACKUP' is not known to ReaR."
fi
