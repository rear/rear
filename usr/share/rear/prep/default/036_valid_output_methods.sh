
# For "rear mkbackup/mkrescue/mkbackuponly/mkopalpba"
# (i.e. for all workflows that run the 'prep' stage)
# check that the OUTPUT method is actually implemented
# i.e. check that a usr/share/rear/output/$OUTPUT directory exists
# and error out when an OUTPUT method seems to be not supported
# to ensure that the user cannot specify a non-working OUTPUT in /etc/rear/local.conf
# see https://github.com/rear/rear/issues/2501
# and cf. usr/share/rear/prep/default/035_valid_backup_methods.sh

if ! test -d "$SHARE_DIR/output/$OUTPUT" ; then
    Error "The OUTPUT method '$OUTPUT' is not supported (no $SHARE_DIR/output/$OUTPUT directory)"
fi
