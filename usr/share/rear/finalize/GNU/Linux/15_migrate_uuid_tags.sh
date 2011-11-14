# migrate fs_uuid_mapping

# skip if no mappings
test -s "$FS_UUID_MAP" || return 0

Log "TAG-15-migrate: $FS_UUID_MAP"

# create the SED_SCRIPT
SED_SCRIPT=""
while read old_uuid new_uuid device ; do
        SED_SCRIPT="$SED_SCRIPT;/${old_uuid}/s/${old_uuid}/${new_uuid}/g"
done < $FS_UUID_MAP

# debug line:
Log "$SED_SCRIPT"

# now run sed
pushd /mnt/local >&8
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
			# if link destination is residing on /proc we skip it silently
			echo $linkdest | grep -q "^/proc" && continue
			LogPrint "Patching '$linkdest' instead of '$file'"
			file="$linkdest"
		else
			LogPrint "Not patching dead link '$file'"
			continue
		fi
	fi

	sed -i "$SED_SCRIPT" "$file"
	StopIfError "Patching '$file' with sed failed."
done

popd >&8
