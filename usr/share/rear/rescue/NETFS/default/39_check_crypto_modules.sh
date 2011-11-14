# cifs module needs crypto module (FAILED: CIFS VFS: mdfour: Crypto md4 allocation error)
if [ "$(url_scheme $BACKUP_URL)" = "cifs" ] ; then
     # for the case cifs module was not yet loaded at this point
     modprobe -q cifs
fi

lsmod=( $(lsmod | cut -d " " -f 1) )

for module in "${lsmod[@]}" ; do
	case "$module" in
		(ecb|md4|md5)
			MODULES_LOAD=( "${MODULES_LOAD[@]}" $module ) ;;
		(des_generic)
			MODULES_LOAD=( "${MODULES_LOAD[@]}" $module ) ;;
		(fscache)
			MODULES_LOAD=( "${MODULES_LOAD[@]}" $module ) ;;
	esac
done
Log "Additional modules to load: ${MODULES_LOAD[@]}"
