# Modules loaded in the initrd should be also loaded in the rescue system
# It is important to load them in the same order to ensure the correct order of SCSI controllers
#
# We keep here all different types of initrd module configurations in a single script because
# distros switch tooling (e.g. SUSE adopted dracut) and otherwise we would end up with several
# symlinks.

# Old SUSE style
if test -s /etc/sysconfig/kernel ; then
    MODULES_LOAD+=(
      $(
        INITRD_MODULES=
        source /etc/sysconfig/kernel
        echo $INITRD_MODULES
      )
    )
fi

# Fedora, Red Hat & new SUSE uses dracut
if test -s /etc/dracut.conf ; then
    MODULES_LOAD+=(
        $(
            add_drivers=
            source /etc/dracut.conf
            for s in /etc/dracut.conf.d/*.conf ; do
                source $s
            done
            echo $add_drivers
        )
    )
fi

# Debian & Ubuntu use initramfs-tools and we include that as-is in 400_copy_modules.sh because we just
# append the initrd modules file to the general modules file. Nevertheless we must ensure that those
# modules are actually included in the rescue system
if test -s /etc/initramfs-tools/modules ; then
    MODULES_LOAD+=(
        $( sed -n -e 's/^\([a-z0-9]\+\).*/\1/p' < /etc/initramfs-tools/modules )
    )
fi

: # set 0 as return value
