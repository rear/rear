
# Include at least the current keyboard mapping in the recovery system.
# Additionally try to include the default US keyboard mapping as fallback.
# Furthermore try to also include other keyboard mappings to support different keyboard layouts
# that is needed when "rear recover" runs on replacement hardware with a different keyboard,
# see https://github.com/rear/rear/pull/1781
# Inform the user about possible issues with keyboard usage in the recovery system
# but use neutral wording for those user messages to avoid false alarm
# except when it fails to include the current keyboard mapping
# (which is no fatal Error because the US keyboard mapping is included as fallback)
# cf. https://github.com/rear/rear/issues/2519
# Only when including the current keyboard mapping failed (i.e. when 'dumpkeys' failed)
# it shows subsequent messages on the user's terminal in any case (via LogPrint and LogPrintError)
# but normally it shows subsequent messages only in debug mode (via DebugPrint).
# On first glance it may look like over-sophisticated code but actually it is user-friendly:
# ReaR follows what Linux distributions have decided (and what their users are used to).
# If the distro provides console-multi-keyboard support, ReaR includes it (without being verbose).
# If the distro has decided that this is not necessary, ReaR aligns with it (without being verbose).
# If the user has installed multi-keyboard support, ReaR aligns with it (without being verbose).
# For details and background information see https://github.com/rear/rear/pull/2520 in particular
# https://github.com/rear/rear/pull/2520#issuecomment-729681053

# Dump current keyboard mapping so that it can be set during recovery system startup
# by etc/scripts/system-setup.d/10-console-setup.sh via "loadkeys /etc/dumpkeys.out":
local original_system_dumpkeys_file="/etc/dumpkeys.out"
local dumpkeys_success="no"
if dumpkeys -f >$ROOTFS_DIR$original_system_dumpkeys_file ; then
    dumpkeys_success="yes"
    DebugPrint "Included current keyboard mapping (via 'dumpkeys -f')"
else
    LogPrintError "Error: Failed to include current keyboard mapping ('dumpkeys -f' failed)"
fi

# Determine the default directory for keymaps:
# Different Linux distributions use a different default directory for keymaps,
# see https://github.com/rear/rear/pull/1781#issuecomment-384322051
# and https://github.com/rear/rear/pull/1781#issuecomment-384331316
# and https://github.com/rear/rear/pull/1781#issuecomment-384560856
# that read (excerpts):
#   SUSE systems: /usr/share/kbd/keymaps
#   Debian 9.2 (stretch): /usr/share/keymaps
#   Centos 7.3.1611 (Core): /lib/kbd/keymaps
#   Fedora release 26 (Twenty Six): /lib/kbd/keymaps
#   Arch Linux: /usr/share/kbd/keymaps
#   Ubuntu 12.04.5 LTS (Precise): /usr/share/keymaps
#   RHEL 6/7: /lib/kbd/keymaps
# so that we have this summary:
#   /usr/share/kbd/keymaps is used by SUSE and Arch Linux
#   /usr/share/keymaps is used by Debian and Ubuntu
#   /lib/kbd/keymaps is used by Centos and Fedora and Red Hat
# It seems newer Debian-based systems (including Ubuntu)
# no longer contain any keymaps directory as part of the base system
# so those distros do no longer provide console-multi-keyboard support by default.
# Optionally installing one (under /usr/share/keymaps) is possible via the console-data package
# cf. https://github.com/rear/rear/issues/2519#issuecomment-729264699
# We do not test and distinguish by Linux distribution identifier strings
# because such tests result an endless nightmare to keep them up-to-date.
# We prefer (whenever possible) to generically test "some real thing".
# Accordingly we test known directories and use the first one that exist.
# The last '' is there to keep keymaps_default_directory empty if none of the directories exist
# which is (currently) not strictly required by the code below but it is cleaner code here:
local keymaps_default_directory=""
for keymaps_default_directory in /usr/share/kbd/keymaps /usr/share/keymaps /lib/kbd/keymaps '' ; do
    test -d "$keymaps_default_directory" && break
done
# Use KEYMAPS_DEFAULT_DIRECTORY if it is explicitly specified by the user:
test $KEYMAPS_DEFAULT_DIRECTORY && keymaps_default_directory="$KEYMAPS_DEFAULT_DIRECTORY"

local info_message=""
if test "$keymaps_default_directory" ; then
    # Try to find and include at least the default US keyboard mapping as fallback:
    if test -d "$keymaps_default_directory" ; then
        local defkeymap_file="$( find $keymaps_default_directory -name 'defkeymap.*' | head -n1 )"
        if test "$defkeymap_file" ; then
            COPY_AS_IS+=( $defkeymap_file )
            info_message="Included default US keyboard mapping $defkeymap_file"
            is_true $dumpkeys_success && DebugPrint "$info_message" || LogPrint "$info_message"
        else
            info_message="No default US keyboard mapping included (no 'defkeymap.*' found in $keymaps_default_directory)"
            is_true $dumpkeys_success && DebugPrint "$info_message" || LogPrintError "$info_message"
        fi
    else
        info_message="No default US keyboard mapping included (no keymaps default directory '$keymaps_default_directory')"
        is_true $dumpkeys_success && DebugPrint "$info_message" || LogPrintError "$info_message"
    fi
else
    info_message="No default US keyboard mapping included (no KEYMAPS_DEFAULT_DIRECTORY specified)"
    is_true $dumpkeys_success && DebugPrint "$info_message" || LogPrintError "$info_message"
fi

# Additionally include other keyboard mappings to also support users with a non-US keyboard
# who can then manually switch to their keyboard mapping (e.g. via a command like "loadkeys de-latin1")
# or who had specdified the KEYMAP that should be used in the recovery system.
# It is not sufficient to include only map.gz or only i386 files because all the include files are also needed.
# Including the whole keymaps default directory increases the recovery system size by about 3 MB
# and including only the 'legacy' subdirectory increases the recovery system size by about 1 MB
# (an usual recovery system size is about 500 MB uncompressed where about 250 MB are firmware files)
# but without the right keyboard mapping it could become an awful annoyance to work in the recovery system
# so that by default and as fallback the whole keymaps default directory is included to be on the safe side,
# cf. https://github.com/rear/rear/pull/1781#issuecomment-384232695
local keymaps_directories=$keymaps_default_directory
# Use KEYMAPS_DIRECTORIES if it is explicitly specified by the user:
contains_visible_char "$KEYMAPS_DIRECTORIES" && keymaps_directories="$KEYMAPS_DIRECTORIES"
if test "$keymaps_directories" ; then
    COPY_AS_IS+=( $keymaps_directories )
    info_message="Included other keyboard mappings in $keymaps_directories"
    is_true $dumpkeys_success && DebugPrint "$info_message" || LogPrint "$info_message"
else
    info_message="No support for different keyboard layouts (neither KEYMAPS_DEFAULT_DIRECTORY nor KEYMAPS_DIRECTORIES specified)"
    is_true $dumpkeys_success && DebugPrint "$info_message" || LogPrintError "$info_message"
fi
