#
# Check that bacula is installed and configuration files exist

# First determine whether we need to restore using bconsole or bextract.

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   ### Bacula support using bextract
   if [ -z "$BEXTRACT_VOLUME" ]; then
      BEXTRACT_VOLUME=*
   fi

   [ -x /usr/sbin/bextract ]
   StopIfError "Bacula executable (bextract) missing or not executable"

   [ -s /etc/bacula/bacula-sd.conf ]
   StopIfError "Bacula configuration file (bacula-sd.conf) missing"

else

   ### Bacula support using bconsole
   [ -x /usr/sbin/bacula-fd ]
   StopIfError "Bacula executable (bacula-fd) missing or not executable"

   [ -s /etc/bacula/bacula-fd.conf ]
   StopIfError "Bacula configuration file (bacula-fd.conf) missing"

   [ -x /usr/sbin/bconsole ]
   StopIfError "Bacula executable (bconsole) missing or not executable"

   [ -s /etc/bacula/bconsole.conf ]
   StopIfError "Bacula configuration file (bconsole.conf) missing"

fi
