# the user has to do the main part here :-)
#
#
LogPrint "Please restore your backup in the Avamar WebGui (to path '$TARGET_FS_ROOT').
When finished enter 'touch /mnt/local/.autorelabel' to ensure that SELinux relabels the files on the next boot.
Afterwards type 'exit' in the shell to finish recovery."
rear_shell "Did you restore the backup to '$TARGET_FS_ROOT'? Are you ready to continue recovery?"
