#
# Stop SELinux if present - see prep/RSYNC/GNU/Linux/200_selinux_in_use.sh
#
test -f $TMP_DIR/selinux.mode || return 0
case "$( basename ${BACKUP_PROG} )" in
    (tar|rsync)
        #cat /selinux/enforce > $TMP_DIR/selinux.mode
        echo "0" > $SELINUX_ENFORCE
        Log "Temporarily stopping SELinux enforce mode with BACKUP=${BACKUP} and BACKUP_PROG=${BACKUP_PROG} backup"
        ;;
    (*) # do nothing
        :
        ;;
esac

