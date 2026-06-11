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

# Do nothing when no initial network setup should be done:
# Using the '[*]' subscript is required here otherwise test gets more than one argument
# which fails with bash error 'bash: test: ...: unary operator expected'
# cf. https://github.com/rear/rear/issues/1068#issuecomment-282741981
# Do this test before "set -e -u" is set to be able to "simply return" here without an
# apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS":
test "${ZYPPER_NETWORK_SETUP_COMMANDS[*]:-}" || return 0

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

# Initial network setup in the target system.
# Use a login shell in between so that one has in the chrooted environment
# all the advantages of a "normal working shell" which means one can write
# the commands inside 'chroot' as one would type them in a normal working shell.
# In particular one can call programs (like 'yast2' or 'ip') by their basename without path
# cf. https://github.com/rear/rear/issues/862#issuecomment-274068914
local network_setup_command=""
local networking_preparation_command=""
for network_setup_command in "${ZYPPER_NETWORK_SETUP_COMMANDS[@]}" ; do
    case "$network_setup_command" in
        (YAST)
            # YaST network card setup in the target system (without having ncurses stuff in the output via TERM=dumb)
            # plus automated response to all requested user input via yes '' (i.e. only plain [Enter] as user input)
            # and ignore non zero exit codes from YaST to avoid that "rear recover" aborts here:
            LogPrint "Initial network setup in the target system via 'yast2 --ncurses lan add name=eth0 ethdevice=eth0 bootproto=dhcp'"
            chroot $TARGET_FS_ROOT /bin/bash --login -c "yes '' | TERM=dumb yast2 --ncurses lan add name=eth0 ethdevice=eth0 bootproto=dhcp" || true
            ;;
        (NETWORKING_PREPARATION_COMMANDS)
            LogPrint "Initial network setup in the target system as specified in NETWORKING_PREPARATION_COMMANDS"
            for networking_preparation_command in "${NETWORKING_PREPARATION_COMMANDS[@]}" ; do
                if test "$networking_preparation_command" ; then
                    # Only report errors to avoid that "rear recover" aborts here:
                    chroot $TARGET_FS_ROOT /bin/bash --login -c "$networking_preparation_command" || LogPrint "Command failed: $networking_preparation_command"
                fi
            done
            ;;
        (*)
            if test "$network_setup_command" ; then
                LogPrint "Initial network setup in the target system via $network_setup_command"
                # Only report errors to avoid that "rear recover" aborts here:
                chroot $TARGET_FS_ROOT /bin/bash --login -c "$network_setup_command" || LogPrint "Command failed: $network_setup_command"
            fi
            ;;
    esac
done

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"

