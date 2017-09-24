### Apply chosen migrations to files on the disk.

if [[ ! -s "$MAPPING_FILE" ]] ; then
    return
fi

# FIXME: Why is there is no matching popd for this pushd?
# Cf. finalize/GNU/Linux/150_migrate_uuid_tags.sh where a popd is at the end.
# If there is intentionally no popd here an explanation why there is no popd is missing.
pushd $TARGET_FS_ROOT >/dev/null
# the funny [] around the first letter make sure that shopt -s nullglob removes this file from the list if it does not exist
# the files without a [] are mandatory, like fstab
for file in     [b]oot/{grub.conf,menu.lst,device.map} [e]tc/grub.* [b]oot/grub/{grub.conf,menu.lst,device.map} \
		[b]oot/grub2/{grub.conf,grub.cfg,menu.lst,device.map} \
                [e]tc/sysconfig/grub [e]tc/sysconfig/bootloader \
                [e]tc/lilo.conf \
                [e]tc/yaboot.conf \
                [e]tc/mtab [e]tc/fstab \
                [e]tc/mtools.conf \
                [e]tc/smartd.conf [e]tc/sysconfig/smartmontools \
                [e]tc/sysconfig/rawdevices \
                [e]tc/security/pam_mount.conf.xml [b]oot/efi/*/*/grub.cfg
        do

	[[ ! -f $file ]] && continue # skip directory or file not found
        # sed -i bails on symlinks, so we follow the symlink and patch the result
        # - absolute link are rebased on $TARGET_FS_ROOT (/etc/fstab => $TARGET_FS_ROOT/etc/fstab)
        # - on dead links we warn and skip them
        if [[ -L "$file" ]] ; then
                linkdest="$(readlink -m "$file" | sed -e "s#^/#$TARGET_FS_ROOT/#" )"
                if test -f "$linkdest" ; then
                    LogPrint "Patching '$linkdest' instead of '$file'"
                    file="$linkdest"
                else
                    LogPrint "Not patching dead link '$file' -> '$linkdest'"
                    continue
                fi
        fi

        if test -s "$file" ; then
            apply_layout_mappings "$file"
        else
            LogPrint "Not Patching empty file ($file)"
        fi
done
