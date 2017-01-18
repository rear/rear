# rebuild the initramfs if the drivers changed
#
# probably not required, but I prefer to rely on this information when it is backed by udev
# FIXME: who is 'I'?
# Perhaps Schlomo Schapiro or someone who made the "P2V patch from Heinlein Support"?
# (see commit 844d50b75ac4b7722f4fee7a5ee3350b93f3adb7)
# And what happens if there is no 'have_udev'? Why is everything o.k. then to just 'return 0'?
have_udev || return 0

# check if we need to do something
if test -s $TMP_DIR/storage_drivers && ! diff $TMP_DIR/storage_drivers $VAR_DIR/recovery/storage_drivers >&8 ; then
	# remember, diff returns 0 if the files are the same

	# merge new drivers with previous initrd modules
	# BUG: we only add modules to the initrd, we don't take old ones out
	#      could be done better, but might not be worth the risk

	# read original INITRD_MODULES from source system
	if [ -f $VAR_DIR/recovery/initrd_modules ]; then
		OLD_INITRD_MODULES=( $(cat $VAR_DIR/recovery/initrd_modules) )
	else
		OLD_INITRD_MODULES=()
	fi

	Log "Original OLD_INITRD_MODULES='${OLD_INITRD_MODULES[@]}'"
	# To see what has been added by the migration process, the new modules are added to the
	# end of the list. To achieve this, we list the old modules twice in the variable
	# NEW_INITRD_MODULES and then add the new modules. Then we use "uniq -u" to filter out
	# the modules which only appear once in the list. The resulting array
	# contains the new modules also.
	NEW_INITRD_MODULES=( ${OLD_INITRD_MODULES[@]} ${OLD_INITRD_MODULES[@]} $( cat $TMP_DIR/storage_drivers ) )

	# uniq INITRD_MODULES

	NEW_INITRD_MODULES=( $(tr " " "\n" <<< "${NEW_INITRD_MODULES[*]}" | sort | uniq -u) )

	Log "New INITRD_MODULES='${OLD_INITRD_MODULES[@]} ${NEW_INITRD_MODULES[@]}'"
	INITRD_MODULES="${OLD_INITRD_MODULES[@]} ${NEW_INITRD_MODULES[@]}"

	WITH_INITRD_MODULES=$( printf '%s\n' ${INITRD_MODULES[@]} | awk '{printf "--with=%s ", $1}' )

	mount -t proc none $TARGET_FS_ROOT/proc
	mount -t sysfs none $TARGET_FS_ROOT/sys

        # Recreate any initrd or initramfs image under $TARGET_FS_ROOT/boot/ with new drivers
        # Images ignored:
        # kdump images as they are build by kdump
        # initramfs rescue images (>= Rhel 7), which need all modules and
        # are created by new-kernel-pkg
        # initrd-plymouth.img (>= Rhel 7), which contains only files needed for graphical boot via plymouth

        unalias ls 2>/dev/null

        for INITRD_IMG in $( ls $TARGET_FS_ROOT/boot/initramfs-*.img $TARGET_FS_ROOT/boot/initrd-*.img | egrep -v '(kdump|rescue|plymouth)' ) ; do
            # Do not use KERNEL_VERSION here because that is readonly in the rear main script:
            kernel_version=$( basename $( echo $INITRD_IMG ) | cut -f2- -d"-" | sed s/"\.img"// )
            INITRD=$( echo $INITRD_IMG | egrep -o "/boot/.*" )
            # FIXME: Why is plain 'echo' used here and not 'LogPrint' or 'echo ... >&7'
            # to print to the original stdout (see 'fd7' in lib/_input-output-functions.sh)?
            echo "Running mkinitrd..."
            # Run mkinitrd directly in chroot without a login shell in between, see https://github.com/rear/rear/issues/862
            local mkinitrd_binary=$( get_path mkinitrd )
            if chroot $TARGET_FS_ROOT $mkinitrd_binary -v -f ${WITH_INITRD_MODULES[@]} $INITRD $kernel_version >&2 ; then
                LogPrint "Updated initrd with new drivers for kernel $kernel_version."
            else
                LogPrint "WARNING:
Failed to create initrd for kernel version '$kernel_version'.
Check '$RUNTIME_LOGFILE' to see the error messages in detail
and decide yourself, whether the system will boot or not.
"
            fi
        done

	umount $TARGET_FS_ROOT/proc $TARGET_FS_ROOT/sys

fi

