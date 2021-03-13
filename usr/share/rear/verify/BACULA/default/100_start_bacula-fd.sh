#
# start the daemons!

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   ### Bacula support using bextract
   if [ -b "$BEXTRACT_DEVICE" ]; then
      mkdir -p /backup
      mount $BEXTRACT_DEVICE /backup || Error "Could not mount Bacula device $BACULA_DEVICE at /backup"
   fi

else

   ### Bacula support using bconsole
   bacula-fd -u root -g bacula -c $BACULA_CONF_DIR/bacula-fd.conf || Error "Cannot start bacula-fd file daemon"

fi
