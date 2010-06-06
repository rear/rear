# migrate disk device mappings

# skip if no mappings
test -s $TMP_DIR/mappings/disk_devices || return 0

Log "TAG-15-migrate: $DISK_DEVICE_MAPPINGS_SED_SCRIPT"

test "$DISK_DEVICE_MAPPINGS_SED_SCRIPT" || BugError "The sed script for the disk device mappings
is missing, it should be defined in verify/GNU/Linux/21_migrate_recovery_configuration.sh."

# now run sed
pushd /mnt/local >/dev/null
# the funny [] around the first letter make sure that shopt -s nullglob removes this file from the list if it does not exist
# the files without a [] are mandatory, like fstab
for file in 	[b]oot/{grub.conf,menu.lst,device.map} [e]tc/grub.* [b]oot/grub/{grub.conf,menu.lst,device.map} \
		[e]tc/sysconfig/grub [e]tc/sysconfig/bootloader \
		[e]tc/lilo.conf \
		[e]tc/mtab etc/fstab \
		[e]tc/mtools.conf \
		[e]tc/smartd.conf [e]tc/sysconfig/smartmontools \
		[e]tc/sysconfig/rawdevices \
		[e]tc/security/pam_mount.conf.xml
	do

	# sed -i bails on symlinks, so we follow the symlink and patch the result
	# on dead links we warn and skip them
	# TODO: maybe we must put this into a chroot so that absolute symlinks will work correctly
	if test -L "$file" ; then
		if linkdest="$(readlink -f "$file")" ; then
			LogPrint "Patching '$linkdest' instead of '$file'"
			file="$linkdest"
		else
			LogPrint "Not patching dead link '$file'"
			continue
		fi
	fi

	sed -i "$DISK_DEVICE_MAPPINGS_SED_SCRIPT" "$file" ||\
		Error "Patching '$file' with sed failed."
done

# we still need to modify the swap entries in /etc/fstab if byid mounting is used
# TODO: keep swap priorities and other options
if grep -q "^/dev/disk/by-id/.*swap" etc/fstab ; then
	sed -i -e '/^\/dev\/disk\/by-id\/.*swap/d' etc/fstab
	for swapfile in $(find $VAR_DIR/recovery -name swap_vol_id) ; do
		device_dir=$(dirname $swapfile)
		swap_device=${device_dir##$VAR_DIR/recovery}
		echo "$swap_device 	swap	swap	defaults	0 0" >> etc/fstab
	done
fi
popd >/dev/null
