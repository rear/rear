# check if NFS user is nobody - for rsync restore this is a NOGO
nfs_uid=$(ls -l "$BUILD_DIR/outputfs" | tail -1 | awk '{print $3}')
case "$nfs_uid" in
    "nobody"|"-1"|"-2"|"4294967294")
        Error "RBME rsync restore will result in a broken system (owner=$nfs_uid).
Please add in $CONFIG_DIR/local.conf BACKUP_OPTIONS=\"nfsvers=3,nolock\"
"
        ;;
esac
