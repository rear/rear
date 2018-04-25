# Console keyboad mapping setup

default_keymap="defkeymap"
original_system_dumpkeys_file="/etc/dumpkeys.out"

keymap=""
# Use KEYMAP if it is explicitly specified by the user:
test $KEYMAP && keymap="$KEYMAP"

# Load keymap:
if test $keymap ; then
    echo "Using $keymap keymap"
    if ! loadkeys $keymap ; then
        echo "Failed to set $keymap keymap" 1>&2 
        if test -s $original_system_dumpkeys_file ; then
            echo "Using keymap of the original system" 1>&2
            if ! loadkeys $original_system_dumpkeys_file ; then
                # To be on the safe side when loadkeys failed try to set at least the default keymap:
                echo "Also failed to set original system keymap, using $default_keymap (US keyboad)" 1>&2
                loadkeys $default_keymap || echo "Even failed to set $default_keymap" 1>&2
            fi
        else
            echo "Using $default_keymap (US keyboad)" 1>&2
            loadkeys $default_keymap || echo "Also failed to set $default_keymap" 1>&2
        fi
    fi
else
    if test -s $original_system_dumpkeys_file ; then
        echo "Using keymap of the original system"
        if ! loadkeys $original_system_dumpkeys_file ; then
            # To be on the safe side when loadkeys failed try to set at least the default keymap:
            echo "Failed to set original system keymap, using $default_keymap (US keyboad)" 1>&2
            loadkeys $default_keymap || echo "Also failed to set $default_keymap" 1>&2
        fi
    fi
fi

