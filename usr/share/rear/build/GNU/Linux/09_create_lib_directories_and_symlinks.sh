# Create lib directories
for libdir in /lib* ; do
	# $libdir always contains a leading / !
	if [ -L $libdir ] ; then
		[ ! -d $ROOTFS_DIR$libdir ]
		BugIfError "Cannot create symlink $libdir instead of directory"

		linktarget=$(readlink -f $libdir)
		linktarget="${linktarget#/}" # strip leading / to make symlink a relative one

		mkdir -p $v "$ROOTFS_DIR/$linktarget" >&2
		StopIfError "Could not mkdir '$ROOTFS_DIR/$linktarget'"

		ln -s $v "$linktarget" $ROOTFS_DIR$libdir >&2
		StopIfError "Could not create symlink '$ROOTFS_DIR$libdir'"
	elif [ -d $libdir ] ; then
		[ ! -L $ROOTFS_DIR$libdir ]
		BugIfError "Cannot create directory $libdir instead of symlink"

		mkdir -p $v $ROOTFS_DIR$libdir >&2
		StopIfError "Could not create directory '$ROOTFS_DIR$libdir'"
	else
		BugError "I never should get here."
	fi
	# add relative symlinks under /usr so that a later copy into those symlinks will put the files into the
	# rescue system and not into the origin system.
	ln -s $v ..$libdir $ROOTFS_DIR/usr$libdir >&2
done
