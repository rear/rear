#
# build/default/960_remove_encryption_keys.sh
#
# Remove the BACKUP_PROG_CRYPT_KEY value from ReaR's initrd
# because the ReaR recovery system must be free of secrets
# cf. the reasoning about SSH_UNPROTECTED_PRIVATE_KEYS in default.conf
# and see https://github.com/rear/rear/issues/2155

# Nothing to do when there is no BACKUP_PROG_CRYPT_KEY value.
# Avoid that the BACKUP_PROG_CRYPT_KEY value is shown in debugscript mode
# cf. the comment of the UserInput function in lib/_input-output-functions.sh
# how to keep things confidential when usr/sbin/rear is run in debugscript mode
# ('2>/dev/null' should be sufficient here because 'test' does not output on stdout):
{ test "$BACKUP_PROG_CRYPT_KEY" ; } 2>/dev/null || return 0

# BACKUP_PROG_CRYPT_KEY must be removed regardless if BACKUP_PROG_CRYPT_ENABLED is true or false
# because when the user has in his etc/rear/local.conf BACKUP_PROG_CRYPT_KEY=my_secret_key
# and BACKUP_PROG_CRYPT_ENABLED=false the BACKUP_PROG_CRYPT_KEY value is still there.

LogPrint "Removing BACKUP_PROG_CRYPT_KEY value from config files in the recovery system"
for configfile in $( find ${ROOTFS_DIR}/etc/rear ${ROOTFS_DIR}/usr/share/rear/conf -name "*.conf" -type f ) ; do
    # Avoid running 'sed' needlessly on files that do not contain 'BACKUP_PROG_CRYPT_KEY=' with its actual value
    # which is the case for default.conf that contains the example BACKUP_PROG_CRYPT_KEY="my_secret_passphrase".
    # Avoid that the BACKUP_PROG_CRYPT_KEY value is shown in debugscript mode as described above.
    # Without '-q' grep would output the BACKUP_PROG_CRYPT_KEY value on stdout which is redirected to the log:
    { grep -q "BACKUP_PROG_CRYPT_KEY=.*$BACKUP_PROG_CRYPT_KEY" $configfile ; } 2>/dev/null || continue
    # It must work for simple unquoted assignment as in
    #   BACKUP_PROG_CRYPT_KEY=my_secret_passphrase
    # but also for more advanced things like
    #   { BACKUP_PROG_CRYPT_KEY='my;secret;passphrase'; } 2>/dev/null
    # cf. the example in doc/user-guide/04-scenarios.adoc
    # To avoid arbitrary syntax matching via complicated regular expressions
    # we simply remove all BACKUP_PROG_CRYPT_KEY values in lines that contain 'BACKUP_PROG_CRYPT_KEY='
    # and we avoid that the BACKUP_PROG_CRYPT_KEY value is shown in debugscript mode as described above:
    if { sed -i -e "/BACKUP_PROG_CRYPT_KEY=/s/$BACKUP_PROG_CRYPT_KEY//g" $configfile ; } 2>/dev/null ; then
        DebugPrint "Removed BACKUP_PROG_CRYPT_KEY value from $configfile"
    else
        LogPrintError "Failed to remove BACKUP_PROG_CRYPT_KEY value from $configfile"
    fi
done

