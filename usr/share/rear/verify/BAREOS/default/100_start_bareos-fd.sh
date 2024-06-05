#
# start the daemons!

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   ### Bareos support using bextract
   if [ -b "$BEXTRACT_DEVICE" ]; then
      mkdir -p /backup
      mount $BEXTRACT_DEVICE /backup
      StopIfError "Could not mount Bareos device $BAREOS_DEVICE at /backup"
   fi

else

   ### Bareos support using bconsole
   # -u <user>: Run as given user (requires starting as root).
   # -g <group>: Run as given group (requires starting as root).
   # -r: Restore only mode. (Backup jobs will fail).
   bareos-fd -u root -g bareos -r
   StopIfError "Cannot start bareos-fd file daemon"

fi
