# on restore it is better to mount the remote filesystem ro

# if it is empty then the result is ro, else the result is ro,$BACKUP_OPTIONS
BACKUP_OPTIONS="ro${BACKUP_OPTIONS:+,}$BACKUP_OPTIONS"

