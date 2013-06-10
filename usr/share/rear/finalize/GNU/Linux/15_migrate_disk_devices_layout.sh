### Apply chosen migrations to files on the disk.

if [[ ! -s "$MAPPING_FILE" ]] ; then
    return
fi

### reuse the script in layout/prepare/default/32_apply_mappings.sh
pushd /mnt/local >&8
# the funny [] around the first letter make sure that shopt -s nullglob removes this file from the list if it does not exist
# the files without a [] are mandatory, like fstab
for file in     [b]oot/{grub.conf,menu.lst,device.map} [e]tc/grub.* [b]oot/grub/{grub.conf,menu.lst,device.map} \
		[b]oot/grub2/{grub.conf,grub.cfg,menu.lst,device.map} \
                [e]tc/sysconfig/grub [e]tc/sysconfig/bootloader \
                [e]tc/lilo.conf \
                [e]tc/mtab [e]tc/fstab \
                [e]tc/mtools.conf \
                [e]tc/smartd.conf [e]tc/sysconfig/smartmontools \
                [e]tc/sysconfig/rawdevices \
                [e]tc/security/pam_mount.conf.xml [b]oot/efi/*/*/grub.cfg
        do

	[[ ! -f $file ]] && continue # skip directory or file not found
        # sed -i bails on symlinks, so we follow the symlink and patch the result
        # on dead links we warn and skip them
        # TODO: maybe we must put this into a chroot so that absolute symlinks will work correctly
        if [[ -L "$file" ]] ; then
                if linkdest="$(readlink -f "$file")" ; then
                        LogPrint "Patching '$linkdest' instead of '$file'"
                        file="$linkdest"
                else
                        LogPrint "Not patching dead link '$file'"
                        continue
                fi
        fi

        tmp_layout=$LAYOUT_FILE
        LAYOUT_FILE="$file"
        source $SHARE_DIR/layout/prepare/default/32_apply_mappings.sh
        LAYOUT_FILE=$tmp_layout
done
