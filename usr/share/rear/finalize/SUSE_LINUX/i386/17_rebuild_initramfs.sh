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

	# set INITRD_MODULES from recovered system
   if test -r /mnt/local/etc/sysconfig/kernel
   then # In SLE12 RC2 /etc/sysconfig/kernel is an useless stub that contains only one line
        #   INITRD_MODULES=""
        # Since SLE12 RC3 /etc/sysconfig/kernel does no longer exist, see bnc#895084 where
        # in particular https://bugzilla.novell.com/show_bug.cgi?id=895084#c7 reads
        #   Best would be to add something like that:
        #   # This replaces old INIRD_MODULES= variable from /etc/sysconfig/kernel
        #   # force_drivers+="kernel_module1 kernel_module2 ..."
        #   in our /etc/dracut.conf.d/01-dist.conf file.
        #   And a similar comment to /etc/sysconfig/kernel
        #   # DO NOT USE THIS FILE ANYMORE. IF YOU WANT TO ENFORCE LOADING
        #   # SPECIFIC KERNEL MODULES SEE /etc/dracut.conf.d/01-dist.conf
        #   # and the dracut (--force-drivers paramter) manpage.
        # Because the comment above reads "probably not required" at least for now
        # there is no support for force_drivers in /etc/dracut.conf.d/01-dist.conf.
	source /mnt/local/etc/sysconfig/kernel
	StopIfError "Could not source '/mnt/local/etc/sysconfig/kernel'"

	Log "Original INITRD_MODULES='$INITRD_MODULES'"
	OLD_INITRD_MODULES=( $INITRD_MODULES ) # use array to split into words
	# To see what has been added by the migration process, the new modules are added to the
	# end of the list. To achieve this, we list the old modules twice in the variable
	# NEW_INITRD_MODULES and then add the new modules. Then we use "uniq -u" to filter out
	# the modules which only appear once in the list. The result array the only
	# contains the new modules.
	NEW_INITRD_MODULES=( $INITRD_MODULES $INITRD_MODULES $( cat $TMP_DIR/storage_drivers ) )

	# uniq INITRD_MODULES

	NEW_INITRD_MODULES=( $(tr " " "\n" <<< "${NEW_INITRD_MODULES[*]}" | sort | uniq -u) )

	Log "New INITRD_MODULES='${OLD_INITRD_MODULES[@]} ${NEW_INITRD_MODULES[@]}'"

	sed -i -e '/^INITRD_MODULES/s/^.*$/#&\nINITRD_MODULES="'"${OLD_INITRD_MODULES[*]} ${NEW_INITRD_MODULES[*]}"'"/' /mnt/local/etc/sysconfig/kernel
   fi

	mount -t proc none /mnt/local/proc
	mount -t sysfs none /mnt/local/sys
	if chroot /mnt/local /bin/bash --login -c "mkinitrd" >&2 ; then
		LogPrint "Recreated initramfs (mkinitrd)."
	else
		LogPrint "WARNING !!!
initramfs creation (mkinitrd) failed, please check '$LOGFILE' to see the error
messages in detail and decide yourself, wether the system will boot or not.
"
	fi
	umount /mnt/local/proc /mnt/local/sys

fi
