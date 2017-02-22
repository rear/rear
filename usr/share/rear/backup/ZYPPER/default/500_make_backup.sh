#
# backup/ZYPPER/default/500_make_backup.sh
# 500_make_backup.sh is the default script name to make a backup
# see backup/readme
# in this case it is not an usual file-based backup/restore method
# see BACKUP=ZYPPER in conf/default.conf
#

test -d $VAR_DIR/backup/$BACKUP || mkdir $verbose -p -m 755 $VAR_DIR/backup/$BACKUP

rpm -qa >$VAR_DIR/backup/$BACKUP/installed_RPMs

