#
# Check that bacula is installed and configuration files exist

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   ### Bacula support using bextract
   has_binary bextract || Error "Bacula bextract is missing"

   [ -s $BACULA_CONF_DIR/bacula-sd.conf ] || Error "Bacula configuration file (bacula-sd.conf) missing"

else

   ### Bacula support using bconsole
   has_binary bacula-fd || Error "Bacula File Daemon is missing"

   [ -s $BACULA_CONF_DIR/bacula-fd.conf ] || Error "Bacula configuration file (bacula-fd.conf) missing"

   has_binary bconsole || Error "Bacula console executable is missing"

   [ -s $BACULA_CONF_DIR/bconsole.conf ] || Error "Bacula configuration file (bconsole.conf) missing"

fi
