if is_true "$BACKUP_PROG_CRYPT_ENABLED" ; then
    REQUIRED_PROGS+=( openssl )
    COPY_AS_IS+=( /etc/crypto-policies ) # see issue #523
fi
