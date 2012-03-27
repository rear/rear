# in skel/default/lib is already made (as a directory)
# Fedora 17: /lib -> usr/lib (major change and this breaks our script)

for libdir in /lib* /usr/lib* ; do
	case $libdir in
	(/lib)	# /lib exists in our skel tree as a dir, we will link /usr/lib to /lib
		# fedora 17 reversed the rule, but we keep our standard
		linktarget=$(readlink -f $libdir)
		linktarget="${linktarget#/}" # strip leading / to make symlink a relative one
		echo ln -s $v ..$libdir $ROOTFS_DIR/usr$libdir >&2
		;;
	(/usr/lib) # /usr/lib should be a link to /lib (see first case statement)
		if [[ ! -L $ROOTFS_DIR$libdir ]]; then
			[[ -d $ROOTFS_DIR$libdir ]] && rmdir $ROOTFS_DIR$libdir >&2
			ln -s $v ../lib $ROOTFS_DIR$libdir >&2
		fi
		;;
	(*)	# all other libs
		if [[ -L $libdir ]]; then
			# ok $libdir is a link, does it exists in $ROOTFS as a dir?
			if [[ ! -d $ROOTFS_DIR$libdir ]]; then
				echo BugIfError "Cannot create symlink $libdir instead of directory"
			fi

			linktarget=$(readlink -f $libdir)
			linktarget="${linktarget#/}" # strip leading / to make symlink a relative one

			mkdir -p $v "$ROOTFS_DIR/$linktarget" 
			ln -s "$linktarget" $ROOTFS_DIR$libdir

		elif [[ -d $libdir ]]; then
			[[ ! -d $ROOTFS_DIR$libdir ]] && mkdir -p $v $ROOTFS_DIR$libdir >&2
			StopIfError "Could not create directory '$ROOTFS_DIR$libdir'"	
		elif [[ -f $libdir ]]; then
			Debug "WARNING: unexpected file '$libdir' found, ignoring"
		else
			BugError "Unknown file '$libdir' found, uncertain what to do"
		fi
		;;
	esac
done
