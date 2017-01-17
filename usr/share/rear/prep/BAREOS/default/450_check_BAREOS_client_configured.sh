#
# Check that bareos is installed and configuration files exist

if [ "$BEXTRACT_DEVICE" -o "$BEXTRACT_VOLUME" ]; then

   ### Bareos support using bextract
   has_binary bextract
   StopIfError "Bareos bextract is missing"

   bareos-sd -t 
   StopIfError "Bareos-sd configuration invalid"

else

   ### Bareos support using bconsole
   has_binary bareos-fd
   StopIfError "Bareos File Daemon is missing"

   bareos-fd -t
   StopIfError "Bareos-fd configuration invalid"

   has_binary bconsole
   StopIfError "Bareos console executable is missing"

   bconsole -t
   StopIfError "Bareos bconsole invalid"

fi
