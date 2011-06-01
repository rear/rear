# find elilo.efi or abort if it cannot be found

# find elilo.efi
if ! test -s "$ELILO_BIN" ; then
	for file in /boot/efi/efi/*/elilo.efi ; do
		if test -s "$file" ; then
			ELILO_BIN="$file"
			break # for loop
		fi
	done

fi

[ -s "$ELILO_BIN" ]
StopIfError "Could not find 'elilo.efi'. Maybe you have to set ELILO_BIN [$ELILO_BIN] ?"
