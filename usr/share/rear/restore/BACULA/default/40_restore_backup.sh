#
# Something basic to get started - V1.0.
#
#
# restore from bacula
#
# Not much to do here. This is a manual restore in that we
# assume that the user knows how to run a restore from bacula and that they
# know what files to restore and to where.

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   if [ -b "$BEXTRACT_DEVICE" -a -d /backup ]; then

      ### Bacula support using bextract and disk archive
      echo "The system is now ready for a restore via Bacula. bextract will
be started for you to restore the required files. It's assumed that you know
what is necessary to restore - typically it will be a full backup.
Be aware, the new root is mounted under /mnt/local.
Do not exit bextract until all files are restored.
"
      read -p "Press ENTER to start bextract" 2>&1

      bextract -V $BEXTRACT_VOLUME /backup /mnt/local

      echo "
If you've exited bextract; it's because the restore has been completed.
The next stage is to reinstall the grub bootloader which will fail if the
correct files have not been restored.
"
      read -p "Press ENTER to continue" 2>&1

   else

      ### Bacula support using bextract and tape archive
      LogPrint "$REQUESTRESTORE_TEXT"

      LogPrint "The bextract command looks like:

   bextract -V $BEXTRACT_VOLUME $BEXTRACT_DEVICE /mnt/local

Where \"$BEXTRACT_VOLUME\" is the required Volume name of the tape,
alternatively, use * if you don't know the volume,
and \"$BEXTRACT_DEVICE\" is the Bacula device name of the tape drive."

      LogPrint "After you reboot, you can restore your Bacula mysql database manually.

   echo \"create database bacula;\" | mysql
   echo \"\. /var/lib/bacula/bacula.sql\" | mysql bacula
   /usr/lib64/bacula/grant_mysql_privileges
   chmod 6770 /var/lib/mysql/bacula
   chgrp bacula /var/lib/mysql/bacula
   service bacula restart

"
      read -p "IMPORTANT: return here and press ENTER when the restore is done:" 2>&1

   fi

else

   ### Bacula support using bconsole

   # Prompt the user that the system recreation has been done and that 
   # bconsole is about to be started.
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

fi

# continue with next script
