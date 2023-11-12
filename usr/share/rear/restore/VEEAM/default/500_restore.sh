#!/bin/bash

# Veeam restore to last backup

rmdir $v /mnt/backup || Error "Could not rmdir /mnt/backup in preparation for Veeam mount"

LogPrint "Mounting latest Veeam full backup (ID '$VEEAM_BACKUPID') to /mnt/backup"
veeamconfig backup mount --id "$VEEAM_BACKUPID" || Error "Failed to mount backup ID: '$VEEAM_BACKUPID'"

if mount | grep -q /mnt/backup; then
    : # veeamconfig backup mount managed to mount the backup
else
    # on some systems veamconfig backup mount doesn't manage (for unclear reasons) to actually mount
    # the loopback device with the backup data, we simply try to do it ourselves
    veeammount -d /tmp/veeamflr/*/FileLevelBackup_0 -p /mnt/backup -o ro -m || Error "Failed to mount Veeam loopback device"
fi

LogPrint "Starting the restore process from Veeam backup at /mnt/backup to $TARGET_FS_ROOT"
if ! tar -C /mnt/backup -c . | tar $v -C $TARGET_FS_ROOT/ -x -i; then
    Error "Failed to copy files and directories from /mnt/backup to /mnt/local"
fi
