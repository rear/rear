# 500_make_rbme_backup.sh
LogPrint "Make a backup via RBME"

# Change the BACKUP_PATH as we want to use the ReaR mount point
if [[ -f /etc/rbme.local.conf ]]; then
   grep -q BACKUP_PATH= /etc/rbme.local.conf && \
       sed -i -e "s;BACKUP_PATH=.*;BACKUP_PATH=$BUILD_DIR/outputfs;" /etc/rbme.local.conf || \
       echo "BACKUP_PATH=$BUILD_DIR/outputfs" >>/etc/rbme.local.conf
else
    echo "BACKUP_PATH=$BUILD_DIR/outputfs" >/etc/rbme.local.conf
fi

rbme localhost 2>&1
RC=$?
# everyone should see this warning
if [[ $RC -gt 0 ]] ; then
    LogPrint "WARNING !
There was an error during archive creation.
Please check the archive and see '$RUNTIME_LOGFILE' for more information.

Since errors are often related to files that cannot be saved by
rbme (rsync), we will continue the $WORKFLOW process. However, you MUST
verify the backup yourself before trusting it !
"
fi
cat /var/log/rbme.log.$(date '+%d')
