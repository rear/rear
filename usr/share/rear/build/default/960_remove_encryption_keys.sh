# Remove all encryption Keys from initrd

if is_false "$BACKUP_PROG_CRYPT_ENABLED" ; then
  return
fi

LogPrint "Removing all encryption Keys from initrd"
for configfile in $(find ${ROOTFS_DIR}/etc/rear ${ROOTFS_DIR}/usr/share/rear/conf -name "*.conf" -type f -print 2>&1)
do
  sed -i -e 's/BACKUP_PROG_CRYPT_KEY=.*/BACKUP_PROG_CRYPT_KEY=""/' $configfile
done

