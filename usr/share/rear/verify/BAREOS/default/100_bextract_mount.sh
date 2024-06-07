#
# start the daemons!

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   ### Bareos support using bextract
   if [ -b "$BEXTRACT_DEVICE" ]; then
      mkdir -p /backup
      mount $BEXTRACT_DEVICE /backup
      StopIfError "Could not mount Bareos device $BAREOS_DEVICE at /backup"
   fi

fi
