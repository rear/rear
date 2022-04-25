if [ -e $VAR_DIR/layout/config/files.md5sum ] ; then
    if ! chroot $TARGET_FS_ROOT md5sum -c --quiet < $VAR_DIR/layout/config/files.md5sum ; then
        LogPrintError "Some configuration files in the restored system do not match the saved layout!"
        return 1
    fi
fi
