#
# restore/ZYPPER/default/940_generate_fstab.sh
# 940_generate_fstab.sh is a finalisation script (see restore/readme)
# that generates etc/fstab in the target system
# according to what of the target system is currently mounted.
# Generating etc/fstab in the target system is needed as prerequirement
# for making a valid initrd via finalize/SUSE_LINUX/i386/170_rebuild_initramfs.sh
# otherwise when booting the recreated system the kernel panics
# with 'unable to mount root fs'
#

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

echo "940_generate_fstab.sh: what is currently mounted"
mount

echo "940_generate_fstab.sh: tree of currently mounted filesystems"
findmnt

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"

local command_before_proceeed="bash -c 'echo exit this sub-shell to proceeed ; exec bash -i'"
test -n "$command_before_proceeed" && eval $command_before_proceeed


