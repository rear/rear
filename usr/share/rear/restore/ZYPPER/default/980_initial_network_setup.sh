#
# restore/ZYPPER/default/980_initial_network_setup.sh
# 980_initial_network_setup.sh is a finalisation script (see restore/readme)
# that does some very basic initial network setup in the target system
# after the files have been restored into the target system
# so that the ineeded executables can be called inside the target system
# to avoid to have them also in the ReaR recovery system.
# This initial network setup is only meant to make the target system
# accessibel from remote in a very basic way (e.g. for 'ssh').
# The actually intended network setup for the target system
# should be done manually by the admin after "rear recover".
#

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

# Do nothing when no initial network setup should be done:
test "${ZYPPER_INITIAL_NETWORK_SETUP:-}" || return

# Initial network setup in the target system.
# Use a login shell in between so that one has in the chrooted environment
# all the advantages of a "normal working shell" which means one can write
# the commands inside 'chroot' as one would type them in a normal working shell.
# In particular one can call programs (like 'yast2' or 'ip') by their basename without path
# cf. https://github.com/rear/rear/issues/862#issuecomment-274068914
case "$ZYPPER_INITIAL_NETWORK_SETUP" in
    (YAST)
        # YaST network card setup in the target system (without having ncurses stuff in the output via TERM=dumb)
        # plus automated respose to all requested user input via yes '' (i.e. only plain [Enter] as user input)
        # and ignoring errors to avoid that "rear recover" aborts here:
        LogPrint "Initial network setup in the target system via 'yast2 --ncurses lan add name=eth0 ethdevice=eth0 bootproto=dhcp'"
        chroot $TARGET_FS_ROOT /bin/bash --login -c "yes '' | TERM=dumb yast2 --ncurses lan add name=eth0 ethdevice=eth0 bootproto=dhcp" || true
        ;;
    (NETWORKING_PREPARATION_COMMANDS)
        LogPrint "Initial network setup in the target system as specified in NETWORKING_PREPARATION_COMMANDS"
        local command=""
        for command in "${NETWORKING_PREPARATION_COMMANDS[@]}" ; do
            # Ignore errors to avoid that "rear recover" aborts here:
            test "$command" && chroot $TARGET_FS_ROOT /bin/bash --login -c "$command" || true
        done
        ;;
    (*)
        LogPrint "Initial network setup in the target system as specified in ZYPPER_INITIAL_NETWORK_SETUP"
        # Ignore errors to avoid that "rear recover" aborts here:
        chroot $TARGET_FS_ROOT /bin/bash --login -c "$ZYPPER_INITIAL_NETWORK_SETUP" || true
        ;;
esac

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"

