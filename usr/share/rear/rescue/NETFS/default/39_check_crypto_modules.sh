# cifs module needs crypto module (FAILED: CIFS VFS: mdfour: Crypto md4 allocation error)
lsmod=( $(lsmod | cut -d " " -f 1) )

for module in "${lsmod[@]}" ; do
	case "$module" in
		(md*)
			MODULES_LOAD=( "${MODULES_LOAD[@]}" $module )
			;;
	esac
done
