#
# Check that bacula is installed and configuration files exist

# First determine whether we need to restore using bconsole or bextract.

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   ### Bacula support using bextract
   if [ -z "$BEXTRACT_VOLUME" ]; then
      BEXTRACT_VOLUME=*
   fi

   if [ ! -x /usr/sbin/bextract ]; then
      ProgressStopIfError 1  "Bacula executable (bextract) missing or not executable"
      exit
   fi

   if [ ! -s /etc/bacula/bacula-sd.conf ]; then
      ProgressStopIfError 1  "Bacula configuration file (bacula-sd.conf) missing"
      exit
   fi

else

   ### Bacula support using bconsole
   if [ ! -x /usr/sbin/bacula-fd ]; then
      ProgressStopIfError 1  "Bacula executable (bacula-fd) missing or not executable"
      exit
   fi

   if [ ! -s /etc/bacula/bacula-fd.conf ]; then
      ProgressStopIfError 1  "Bacula configuration file (bacula-fd.conf) missing"
      exit
   fi

   if [ ! -x /usr/sbin/bconsole ]; then
      ProgressStopIfError 1  "Bacula executable (bconsole) missing or not executable"
      exit
   fi

   if [ ! -s /etc/bacula/bconsole.conf ]; then
      ProgressStopIfError 1  "Bacula configuration file (bconsole.conf) missing"
      exit
   fi

fi
