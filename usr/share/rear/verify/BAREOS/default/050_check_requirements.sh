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

   bareos-sd -t 
   StopIfError "Bareos-sd configuration invalid"

else

   ### Bareos support using bconsole
   [ -x /usr/sbin/bareos-fd ]
   StopIfError "Bareos executable (bareos-fd) missing or not executable"

   bareos-fd -t
   StopIfError "Bareos-fd configuration invalid"

   [ -x /usr/sbin/bconsole ]
   StopIfError "Bareos executable (bconsole) missing or not executable"

   bconsole -t
   StopIfError "Bareos bconsole configuration invalid"

fi
