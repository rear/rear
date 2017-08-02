#
# restore/YUM/default/950_grub_mkconfig.sh
# 950_grub_mkconfig is a finalisation script (see restore/readme)
# that runs grubby in the target system
# after the files have been restored into the target system
# (i.e. so that GRUB is installed in the target system).
#

# If /sbin/grub-install does not exist on the target system, we don't have grub (legacy)
test -e $TARGET_FS_ROOT/sbin/grub-install || return

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

# Ensure /proc /sys /dev from the installation system are available in the target system
# which are needed to run grub2-mkconfig in the target system.
# FIXME: If a mount command fails proceed "bona fide" by assuming it is already mounted:
mount -t proc none $TARGET_FS_ROOT/proc || true
mount -t sysfs sys $TARGET_FS_ROOT/sys || true
mount -o bind /dev $TARGET_FS_ROOT/dev || true

# FIXME: This should not be needed here but work via finalize/SUSE_LINUX/i386/170_rebuild_initramfs.sh
# Make initrd verbosely in the target system:
#chroot $TARGET_FS_ROOT /sbin/mkinitrd -v

cp -a $TARGET_FS_ROOT/boot/grub/grub.conf $TARGET_FS_ROOT/boot/grub/grub.conf.bak
# Generate new grub menu entries based on initial entry, which may no longer be valid.
# From:  https://rewoo.wordpress.com/2013/02/08/repairing-a-broken-grub-conf-in-centos-2/
for kernel in $TARGET_FS_ROOT/boot/vmlinuz-*
do
	version=$(echo $kernel | awk -F'vmlinuz-' '{print $NF}')
	chroot $TARGET_FS_ROOT /sbin/grubby \
		--add-kernel="/boot/vmlinuz-${version}" \
		--initrd="/boot/initramfs-${version}.img" \
		--title="CentOS (${version})" \
		--copy-default \
		--make-default \
		--bad-image-okay	# bad-image-okay allows grubby to reuse entries with missing
					# files, which is very possible on our restored target system
done

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"

