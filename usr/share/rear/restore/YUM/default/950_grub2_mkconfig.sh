#
# restore/YUM/default/950_grub2_mkconfig.sh
# 950_grub2_mkconfig is a finalisation script (see restore/readme)
# that runs grub2-mkconfig in the target system
# after the files have been restored into the target system
# (i.e. so that GRUB2 is installed in the target system).
# Running grub2-mkconfig is needed as prerequirement
# for running grub2-install in finalize/Linux-i386/660_install_grub2.sh
# otherwise there is no /boot/grub2/grub.cfg in the target system
# and then finalize/Linux-i386/660_install_grub2.sh still "just works"
# (i.e. it does not error out when there is no /boot/grub2/grub.cfg)
# but the recreated system will not boot (stops at "grub>" bootloader prompt).
#

# If /usr/sbin/grub2-mkconfig does not exist on the target system, we cannot run it
test -e $TARGET_FS_ROOT/usr/sbin/grub2-mkconfig || return

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

# Run grub2-mkconfig in the target system.
# A login shell in between is needed when shell scripts are called insinde 'chroot'
# cf. https://github.com/rear/rear/issues/862#issuecomment-282039428
# In particular grub2-mkconfig is a shell script that calls other shell scripts:
chroot $TARGET_FS_ROOT /bin/bash --login -c '/usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg'

# FIXME: This should not be needed here but work via finalize/Linux-i386/660_install_grub2.sh
# Install bootloader in the target system:
chroot $TARGET_FS_ROOT /usr/sbin/grub2-install --force /dev/sda

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"

