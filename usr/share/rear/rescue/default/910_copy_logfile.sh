# Copy current unfinished logfile to initramfs for debug purpose.
# Usually REAR_LOGFILE=/var/log/rear/rear-$HOSTNAME.log
# The REAR_LOGFILE name set by main script from LOGFILE in default.conf
# but later user config files are sourced in main script where LOGFILE can be set different
# so that the user config LOGFILE basename (except a trailing '.log') is used as target logfile name:
logfile_basename=$( basename $LOGFILE )
LogPrint "Copying logfile $REAR_LOGFILE into initramfs as '/tmp/${logfile_basename%.*}-partial-$(date -Iseconds).log'"
mkdir -p $v $ROOTFS_DIR/tmp >&2
cp -a $v $REAR_LOGFILE $ROOTFS_DIR/tmp/${logfile_basename%.*}-partial-$(date -Iseconds).log >&2

