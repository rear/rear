REQUIRED_PROGS+=( rbme )

if test -z "$BACKUP_URL" ; then
    Error "Missing BACKUP_URL=nfs://HOST/PATH !"
fi

scheme="$(url_scheme "$BACKUP_URL")"
case $scheme in
    (nfs)
        PROGS+=(
        showmount
        mount.$(url_scheme "$BACKUP_URL")
        umount.$(url_scheme "$BACKUP_URL")
        )
	MODULES+=( nfs nfsd )
        ;;
    (*)
        return
        ;;
esac

