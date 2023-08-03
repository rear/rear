#
# restore/ZYPPER/default/970_set_root_password.sh
# 970_set_root_password.sh is a finalisation script (see restore/readme)
# that sets the initial root password in the target system
# after the files have been restored into the target system
# so that the 'passwd' executable can be called inside the target system
# to avoid a 'passwd' executable is needed in the ReaR recovery system.
# This initial root password should not be the actually intended root password
# because its value is stored in usually insecure files (e.g. /etc/rear/local.conf)
# which are included in the ReaR recovery system that is stored
# in also usually insecure files (like ISO images e.g. rear-HOSTNAME.iso)
# so that the actually intended root password for the target system
# should be set manually by the admin after "rear recover".
#

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

# As fallback use 'root' as root password in the target system.
# A non-empty fallback is needed because 'passwd' does not accept empty input:
{ local root_password="root"
  # If SSH_ROOT_PASSWORD is specified used that as root password in the target system:
  test "$SSH_ROOT_PASSWORD" && root_password="$SSH_ROOT_PASSWORD"
  # If ZYPPER_ROOT_PASSWORD is specified used that as root password in the target system:
  test "$ZYPPER_ROOT_PASSWORD" && root_password="$ZYPPER_ROOT_PASSWORD"
} 2>>/dev/$SECRET_OUTPUT_DEV

# Set the root password in the target system.
# Use a login shell in between so that one has in the chrooted environment
# all the advantages of a "normal working shell" which means one can write
# the commands inside 'chroot' as one would type them in a normal working shell.
# In particular one can call programs (like 'passwd') by their basename without path
# cf. https://github.com/rear/rear/issues/862#issuecomment-274068914
{ chroot $TARGET_FS_ROOT /bin/bash --login -c "echo -e '$root_password\n$root_password' | passwd root" ; } 2>>/dev/$SECRET_OUTPUT_DEV

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"

