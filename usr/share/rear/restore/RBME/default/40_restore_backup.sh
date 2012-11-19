
if [[ -z "$RBME_BACKUP" ]] ; then
    Error "No RBME backup selected. Aborting."
fi

scheme=$(url_scheme "$BACKUP_URL")
case $scheme in
    (local|nfs)
        LogPrint "Restoring from backup $RBME_BACKUP. This can take some time."
        [[ -d $BUILD_DIR/outputfs/$HOSTNAME/$RBME_BACKUP ]]
        BugIfError "Backup $RBME_BACKUP not found in $BACKUP_URL$HOSTNAME/."
        rsync -a $BUILD_DIR/outputfs/$HOSTNAME/$RBME_BACKUP/* /mnt/local/
        ;;
    *)
        return
        ;;
esac
