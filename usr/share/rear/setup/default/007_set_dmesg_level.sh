
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# In the ReaR recovery system /etc/scripts/boot calls hardcoded 'dmesg -n 5'
# to limit console logging for kernel messages to level 5 during recovery system startup
# (the usual default shows too many kernel messages that disturb the intended ReaR messages)
# so that kernel error and warning messages appear (intermixed with ReaR messages) on the console
# so the user can notice when things go wrong in kernel area which helps to understand problems,
# see https://github.com/rear/rear/issues/3107
# and https://github.com/rear/rear/pull/3108

# Additionally call 'dmesg -n [4-6]' here depending on verbose and debug modes for ReaR
# if we are inside the ReaR recovery system (we must not change 'dmesg' on the original system),
# see https://github.com/rear/rear/issues/3107#issuecomment-1855797222
test "$RECOVERY_MODE" || return 0

# Now we are inside the ReaR recovery system
# and 'setup' stage scripts are only run by the following workflows
# recover layoutonly restoreonly finalizeonly mountonly
# see https://github.com/rear/rear/pull/3112#issuecomment-1862770147
# so for those workflows 'dmesg -n [4-6]' is set depending on verbose and debug modes for ReaR.
# The remaining workflows that can run within the recovery system
# (cf. init/default/050_check_rear_recover_mode.sh)
# are opaladmin and help which run with 'dmesg -n 5' from /etc/scripts/boot

# Set minimum dmesg level 4 to show at least kernel error conditions and more severe issues on the console
local dmesg_level=4
# In verbose and debug mode increase dmesg level to 5 to also show kernel warnings on the console
# (kernel warning messages are usually needed because some errors are reported as warnings)
# and because 'rear recover' is always verbose this matches what is set in /etc/scripts/boot
test "$VERBOSE" && dmesg_level=5
# In debugscript mode increase dmesg level to 6 to also show significant kernel conditions
test "$DEBUGSCRIPTS" && dmesg_level=6
# dmesg level 7 shows lots of informational kernel messages
# that are normally not helpful for debugging issues during 'rear recover'
# see https://github.com/rear/rear/pull/3112#issue-2048550351
# and dmesg level 8 (kernel debug-level messages) is over the top for 'rear recover'
# see https://github.com/rear/rear/issues/3107#issuecomment-1855831572
# and if 'dmesg -n 7' (or something else) is needed it can be called via PRE_RECOVERY_COMMANDS
# (therefore this script must run before setup/default/010_pre_recovery_script.sh)
# so what we set here is only the default behaviour
DebugPrint "Setting dmesg level $dmesg_level"
dmesg -n $dmesg_level

