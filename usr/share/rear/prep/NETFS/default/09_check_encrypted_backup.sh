[[ -z "$BACKUP_PROG_CRYPT_ENABLED" ]] && return   # no encryption requested
[[ $BACKUP_PROG_CRYPT_ENABLED -ne 1 ]] && return   # no encryption requested
REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" openssl )
COPY_AS_IS=( ${COPY_AS_IS[@]} /etc/crypto-policies ) # see issue #523
