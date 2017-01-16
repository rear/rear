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
   bareos-fd -u root -g bareos
   StopIfError "Cannot start bareos-fd file daemon"

fi
