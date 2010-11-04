#
# Something basic to get started - V1.0.
#
# 
# restore from bacula
#
# Not much to do here. This is a manual restore in that we
# assume that the user knows how to run a restore from bacula and that they
# know what files to restore and to where.
#
# Prompt the user that the system recreation has been done and that 
# bconsole is about to be started.
#
echo "The system is now ready for a restore via Bacula. bconsole will 
be started for you to restore the required files. It's assumed that you know
what is necessary to restore - typically it will be a full backup. 
Be aware, the new root is mounted under /mnt/local.
Do not exit bconsole until all files are restored

Press ENTER to start bconsole"
read

bconsole

echo "
If you've exited bconsole, it's because the restore has been completed.
The next stage is to reinstall the grub bootloader which will fail if the 
correct files have not been restored

Press ENTER to continue
"
read

# continue with next script
