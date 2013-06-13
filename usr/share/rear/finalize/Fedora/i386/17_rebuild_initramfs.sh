# rebuild the initramfs if the drivers changed
#
# probably not required, but I prefer to rely on this information when it
# is backed by udev
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

        mount -t proc none /mnt/local/proc
        mount -t sysfs none /mnt/local/sys

        # Watch for any initrd or initramfs in original grub.conf and recreate it with the new drivers
        for INITRD_IMG in `grep -v "#" /mnt/local/boot/grub/grub.conf | egrep -o '(initrd-.*img|initramfs-.*img)'` ; do
            KERNEL_VERSION=`echo $INITRD_IMG | cut -f2- -d"-" | sed s/".img"//`
            if chroot /mnt/local /bin/bash --login -c "mkinitrd -v -f ${WITH_INITRD_MODULES[@]} $INITRD_IMG $KERNEL_VERSION" >&2 ; then
                        LogPrint "Updated initramfs with new drivers for installed Kernel $KERNEL_VERSION."
            else
                        LogPrint "WARNING !!!
initramfs creation for Kernel $KERNEL_VERSION failed, please check '$LOGFILE' to see the error
messages in detail and decide yourself, wether the system will boot or not.
"
            fi
        done

        umount /mnt/local/proc /mnt/local/sys

fi
