#
# Check that bareos is installed and configuration files exist

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   ### Bareos support using bextract
   has_binary bextract
   StopIfError "Bareos bextract is missing"

   [ -s /etc/bareos/bareos-sd.conf ]
   StopIfError "Bareos configuration file (bareos-sd.conf) missing"

else

   ### Bareos support using bconsole
   has_binary bareos-fd
   StopIfError "Bareos File Daemon is missing"

   [ -s /etc/bareos/bareos-fd.conf ]
   StopIfError "Bareos configuration file (bareos-fd.conf) missing"

   has_binary bconsole
   StopIfError "Bareos console executable is missing"

   [ -s /etc/bareos/bconsole.conf ]
   StopIfError "Bareos configuration file (bconsole.conf) missing"

fi
