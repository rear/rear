#
# Check that bareos is installed and configuration files exist

# First determine whether we need to restore using bconsole or bextract.

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   ### Bareos support using bextract
   if [ -z "$BEXTRACT_VOLUME" ]; then
      BEXTRACT_VOLUME=*
   fi

   [ -x /usr/sbin/bextract ]
   StopIfError "Bareos executable (bextract) missing or not executable"

   [ -s /etc/bareos/bareos-sd.conf ]
   StopIfError "Bareos configuration file (bareos-sd.conf) missing"

else

   ### Bareos support using bconsole
   [ -x /usr/sbin/bareos-fd ]
   StopIfError "Bareos executable (bareos-fd) missing or not executable"

   [ -s /etc/bareos/bareos-fd.conf ] || [ -s /etc/bareos/bareos-fd.d/client/myself.conf ]
   StopIfError "Bareos configuration file (bareos-fd.conf) missing"

   [ -x /usr/sbin/bconsole ]
   StopIfError "Bareos executable (bconsole) missing or not executable"

   [ -s /etc/bareos/bconsole.conf ]
   StopIfError "Bareos configuration file (bconsole.conf) missing"

fi
