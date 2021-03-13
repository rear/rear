
scheme=$(url_scheme "$BACKUP_URL")
case $scheme in
    (nfs)
        PROGS+=(
        showmount
        mount.$(url_scheme $BACKUP_URL)
        umount.$(url_scheme $BACKUP_URL)
        )
        ;;
    (*)
        return
        ;;
esac

