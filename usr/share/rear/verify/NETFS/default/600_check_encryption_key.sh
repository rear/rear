#
# verify/NETFS/default/600_check_encryption_key.sh
#
# Error out when BACKUP_PROG_CRYPT_ENABLED but no BACKUP_PROG_CRYPT_KEY is set.

is_true "$BACKUP_PROG_CRYPT_ENABLED" || return 0

# There is no BACKUP_PROG_CRYPT_KEY value in etc/rear/local.conf in the recovery system
# (it was removed by build/default/960_remove_encryption_keys.sh see the comment there)
# so we need to ensure the BACKUP_PROG_CRYPT_KEY value was manually set again.
# Avoid that the BACKUP_PROG_CRYPT_KEY value is shown in debugscript mode
# cf. the comment of the UserInput function in lib/_input-output-functions.sh
# how to keep things confidential when usr/sbin/rear is run in debugscript mode
# ('2>/dev/null' should be sufficient here because 'test' does not output on stdout):
{ test "$BACKUP_PROG_CRYPT_KEY" ; } 2>/dev/null || Error "BACKUP_PROG_CRYPT_KEY must be set for backup archive decryption"
LogPrint "Decrypting backup archive with key defined in BACKUP_PROG_CRYPT_KEY"

