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
   [ -f /etc/bareos/bareos-fd.conf ] && bareos-fd -u root -g bareos -c /etc/bareos/bareos-fd.conf
   StopIfError "Cannot start bareos-fd file daemon"
   [ -f /etc/bareos/bareos-fd.d/client/myself.conf ] && bareos-fd -u root -g bareos -c /etc/bareos
   StopIfError "Cannot start bareos-fd file daemon"

fi
