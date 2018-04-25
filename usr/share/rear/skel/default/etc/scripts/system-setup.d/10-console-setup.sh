
# Console keyboad mapping setup.
#
# With topmost priority it tries to set what the user specified as KEYMAP
# which may fail when needed keymap files are missing (e.g. include files).
# With second priority it tries to set the keymap of the original system.
# As fallback it tries to set at least the default (US keyboad) keymap.

default_keymap="defkeymap"
original_system_dumpkeys_file="/etc/dumpkeys.out"

# Set KEYMAP if it is explicitly specified by the user:
if test $KEYMAP ; then
    echo "Using $KEYMAP keymap"
    if ! loadkeys $KEYMAP ; then
        # If setting KEYMAP failed try to set the keymap of the original system:
        echo "Failed to set $KEYMAP keymap" 1>&2 
        if test -s $original_system_dumpkeys_file ; then
            echo "Using keymap of the original system" 1>&2
            if ! loadkeys $original_system_dumpkeys_file ; then
                # To be on the safe side when loadkeys failed try to set at least the default keymap:
                echo "Also failed to set original system keymap, using $default_keymap (US keyboad)" 1>&2
                loadkeys $default_keymap || echo "Even failed to set $default_keymap" 1>&2
            fi
        else
            # When setting KEYMAP failed and there is no original_system_dumpkeys_file set the default keymap:
            echo "Using $default_keymap (US keyboad)" 1>&2
            loadkeys $default_keymap || echo "Also failed to set $default_keymap" 1>&2
        fi
    fi
else
    # When there no KEYMAP specified try to set the keymap of the original system:
    if test -s $original_system_dumpkeys_file ; then
        echo "Using keymap of the original system"
        if ! loadkeys $original_system_dumpkeys_file ; then
            # To be on the safe side when loadkeys failed try to set at least the default keymap:
            echo "Failed to set original system keymap, using $default_keymap (US keyboad)" 1>&2
            loadkeys $default_keymap || echo "Also failed to set $default_keymap" 1>&2
        fi
    else
        # When there is neither KEYMAP nor original_system_dumpkeys_file set the default keymap:
        echo "Using $default_keymap (US keyboad)"
        loadkeys $default_keymap || echo "Failed to set $default_keymap" 1>&2
    fi
fi

