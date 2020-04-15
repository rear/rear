# purpose of the script is to detect some important KERNEL CMDLINE options on the current system
# we should also use in rescue mode (automatically update KERNEL_CMDLINE array variable).

# Scanning current kernel cmdline to look for important option ($COPY_KERNEL_PARAMETERS) to include in KERNEL_CMDLINE
for current_kernel_option in $( cat /proc/cmdline ); do
    # Get the current kernel option name (part before leftmost "=") and
    # add the whole option (with value) to new_kernel_options_to_add array
    # if the option name is part of COPY_KERNEL_PARAMETERS array:
    if IsInArray "${current_kernel_option%%=*}" "${COPY_KERNEL_PARAMETERS[@]}" ; then
        new_kernel_options_to_add+=( "$current_kernel_option" )
    fi
done

# Verify if the kernel option we want to add to KERNEL_CMDLINE are not already set/force by the user in the rear configuration.
# If yes, the parameter set in the configuration file have the priority and superseed the current kernel option.
for new_kernel_option in "${new_kernel_options_to_add[@]}" ; do
    new_kernel_option_keyword="${new_kernel_option%%=*}"

    for rear_kernel_option in $KERNEL_CMDLINE ; do
        # Check if a kernel option key without value parameter (everything before =) is not already present in rear KERNEL_CMDLINE array.
        if test "$new_kernel_option_keyword" = "${rear_kernel_option%%=*}" ; then
            Log "Current kernel option [$new_kernel_option] supperseeded by [$rear_kernel_option] in your rear configuration: (KERNEL_CMDLINE)"
            # Continue with the next new_kernel_option (i.e. continue the outer 'for' loop):
            continue 2
        fi
    done

    if test "net.ifnames" = "$new_kernel_option_keyword" ; then
        # If we are using persistent naming do not add net.ifnames to KERNEL_CMDLINE
        # see https://github.com/rear/rear/pull/1874
        # and continue with the next new_kernel_option:
        is_persistent_ethernet_name $( ip r | awk '$2 == "dev" && $8 == "src" { print $3 }' | sort -u | head -1 ) && continue
    fi

    LogPrint "Adding $new_kernel_option to KERNEL_CMDLINE"
    KERNEL_CMDLINE="$KERNEL_CMDLINE $new_kernel_option"
done

# In case we added 'KERNEL_CMDLINE="$KERNEL_CMDLINE net.ifnames=0"' to /etc/rear/local.conf, but we have no idea if we
# are using persistent naming or not then we should protect the rescue image from doing stupid things and remove
# the keyword (and value) in a preventive way in case "persistent naming is in use".
# And, to be clear the /proc/cmdline did not contain the keyword net.ifnames

if is_persistent_ethernet_name $( ip r | awk '$2 == "dev" && $8 == "src" { print $3 }' | sort -u | head -1 ) ; then
    # persistent naming is in use
    # When the KERNEL_CMDLINE does NOT contain net.ifnames=0 silently return
    echo $KERNEL_CMDLINE | grep -q 'net.ifnames=0' || return
    # Remove net.ifnames=0 from KERNEL_CMDLINE
    KERNEL_CMDLINE=$( echo $KERNEL_CMDLINE | sed -e 's/net.ifnames=0//' )
    LogPrint "Removing net.ifnames=0 from KERNEL_CMDLINE"
fi
