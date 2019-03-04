
# Activating multipath if BOOT_OVER_SAN variable is true.
# or if multipath device are present in LAYOUT_FILE.

# In case of migration to a BOOT_OVER_SAN server, you need to be able
# to detect new multipath device even if there are no multipath device present
# in the Layout file (original machine not multipathed). (#1309)
if grep -q '^multipath' "$LAYOUT_FILE" || is_true "$BOOT_OVER_SAN" ; then
    LogPrint "Setting up multipathing"

    # We need to create a multipath.conf if it does not exists (needed by Fedora based OS)
    # and only if NO multipath device were detecting during the backup (migration) => means no multipath in LAYOUT_FILE
    if [ ! -f /etc/multipath.conf ] && ! grep -q '^multipath' "$LAYOUT_FILE" ; then
        if has_binary mpathconf &> /dev/null ; then
            LogPrint "Using mpathconf to configure multipath with friendly_names and find_multipath options"

            # /etc/multipath dir need to be present before mpathconf runs
            [ ! -d /etc/multipath ] && mkdir -p /etc/multipath

            # create default multipath.conf with friendly_names and find_multipath options
            mpathconf --enable --user_friendly_names y --find_multipaths y --with_module y --with_multipathd y
        else
            # Activate multipath with most commonly used options : user_friendly_names
            LogPrint "mpathconf not found... creating default multipath.conf file with friendly_names"
            echo "
defaults {
        user_friendly_names yes
        bindings_file "/etc/multipath/bindings"
}

blacklist {
}" >> /etc/multipath.conf
        fi
    fi

    # it is recommended to reload udev in order to have /sys updated with information from all the device path before activating multipath. 
    # This could avoid situation like https://github.com/rear/rear/issues/2016 and https://github.com/rear/rear/issues/2002
    udevadm control --reload-rules
    udevadm trigger
    # Wait for udev trigger to finish device detection/creation
    udevadm settle

    # multipath activation. 
    LogPrint "Activating multipath"
    list_mpath_device=1
    modprobe dm-multipath >&2 && LogPrint "multipath activated" || LogPrint "Failed to load dm-multipath module"

    # Asking to the User what to do after multipath command return 1.
    # It could be because no multipath device were found (sles11/rhel6)
    # or a real problem in the multipath configuration.
    prompt="Failed to get multipath device list or no multipath device found."

    rear_workflow="rear $WORKFLOW"
    unset choices
    choices[0]="Multipath is not needed. Continue recovery."
    choices[1]="Run multipath with debug options."
    choices[2]="Enter into rear-shell to manually debug multipath."
    choices[3]="Abort '$rear_workflow'"
    choice=""
    wilful_input=""

    # looping on this menu while multipath failed to list device.
    # Note: On sles11/rhel6, multipath failed if no multipath device is found.
    while ! multipath ; do
        echo
        choice="$( UserInput -I MULTIPATH_FAILED_TO_LIST_DEVICE -p "$prompt" -D "${choices[0]}" "${choices[@]}")"&& wilful_input="yes" || wilful_input="no"
        case "$choice" in
            (${choices[0]})
                # continue recovery without multipath
                is_true "$wilful_input" && LogPrint "User confirmed continuing without multipath" || LogPrint "Continuing '$rear_workflow' by default"
                LogPrint "You should consider removing BOOT_ON_SAN parameter from your rear configuration file if you don't need multipath on this server."

                # Avoid to list mpath device.
                list_mpath_device=0
                # unload multipath module
                LogPrint "Unload dm-multipath module"
                rmmod dm-multipath
                break
                ;;
            (${choices[1]})
                # Run multipath in debug level
                LogPrint "starting multipath -v3 (debug mode)"
                multipath -v3
                ;;
            (${choices[2]})
                # Exit to shell to debug multipathing issue
                rear_shell "Do you want to go back to '$rear_workflow' ?"
                ;;
            (${choices[3]})
                # Abort rear recovery
                abort_recreate
                Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}"
                ;;
        esac
    done

    if is_true $list_mpath_device ; then

        # start multipathd
        if has_binary multipathd &> /dev/null ; then
            LogPrint "Starting multipath daemon"
            multipathd >&2 && LogPrint "multipathd started" || LogPrint "Failed to start multipathd"
        fi

        # Search and list mpath device.
        # If multipath is used with "friendly_name" option, the output of "multipath -l" is
        #   <friendly_mpath_name> (<mpath UUID>) <dm-name> <Vendor,type>
        #   rootvg (3600507680c82004cf800000000000306) dm-2 IBM,2145 
        # while it is a bit different when "friendly_name" is disabled
        #   <mpath UUID> <dm-name> <Vendor,type>
        #   36005076400810051380000000000007b dm-2 IBM,2145
        # so that "dm-" can be the 3rd or 2nd field which means
        # we let awk print the line where "dm-" appears
        # cf. https://github.com/rear/rear/pull/1889
        LogPrint "Listing multipath device found"
        LogPrint "$(multipath -l | awk '/dm-/{ DEVICES=$0 } ; $1~/size=/ { print DEVICES" "$1 }' 2>&1)"
    fi
fi

### Create multipath devices (at least partitions on them).
function create_multipath() {
    local device=$1
    if grep "^multipath $device " "$LAYOUT_FILE" 1>&2 ; then
        Log "Found current or former multipath device $device in $LAYOUT_FILE: Creating partitions on it"
        create_partitions "$device"
    fi
}
