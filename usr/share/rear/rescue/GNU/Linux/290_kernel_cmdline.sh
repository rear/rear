# Purpose of the script is to get the COPY_KERNEL_PARAMETERS on the current system
# to be used in the rescue/recovery system via automated update of KERNEL_CMDLINE.

# Also protect the rescue/recovery system by removing net.ifnames=0 from KERNEL_CMDLINE
# if net.ifnames=0 is in KERNEL_CMDLINE but persistent network interface naming is used:
local persistent_naming='no'
is_persistent_ethernet_name $( ip route | awk '$2 == "dev" && $8 == "src" { print $3 }' | sort -u | head -n1 ) && persistent_naming='yes'

# Scan current kernel cmdline for options in COPY_KERNEL_PARAMETERS to be included in KERNEL_CMDLINE:
local current_kernel_option
local new_kernel_options_to_add=()
for current_kernel_option in $( cat /proc/cmdline ) ; do
    # Get the current kernel option name (part before leftmost "=") and
    # add the whole option (with value) to new_kernel_options_to_add array
    # if the option name is part of COPY_KERNEL_PARAMETERS array:
    IsInArray "${current_kernel_option%%=*}" "${COPY_KERNEL_PARAMETERS[@]}" && new_kernel_options_to_add+=( "$current_kernel_option" )
done

# Check if the kernel options we want to add to KERNEL_CMDLINE are already set by the user in KERNEL_CMDLINE.
# If yes, the user setting has priority and superseds the kernel option from the current system.
# For the check use the existing KERNEL_CMDLINE when this script is started
# and not the modified KERNEL_CMDLINE with already added kernel options
# to make it possible to add several kernel options by this script
# with same kernel option keyword like console=ttyS0,9600 console=tty0
# see https://github.com/rear/rear/pull/2749#issuecomment-1197843273
# and https://github.com/rear/rear/pull/2844
local existing_kernel_cmdline="$KERNEL_CMDLINE"
local existing_kernel_option new_kernel_option new_kernel_option_keyword
for new_kernel_option in "${new_kernel_options_to_add[@]}" ; do
    new_kernel_option_keyword="${new_kernel_option%%=*}"
    for existing_kernel_option in $existing_kernel_cmdline ; do
        if test "$new_kernel_option_keyword" = "${existing_kernel_option%%=*}" ; then
            LogPrint "Not adding '$new_kernel_option' (superseded by existing '$existing_kernel_option' in KERNEL_CMDLINE)"
            # Continue with the next new_kernel_option (i.e. continue the outer 'for' loop):
            continue 2
        fi
    done
    # If we are using persistent naming do not add net.ifnames to KERNEL_CMDLINE
    # see https://github.com/rear/rear/pull/1874
    # and continue with the next new_kernel_option:
    if test "net.ifnames" = "$new_kernel_option_keyword" ; then
        if is_true $persistent_naming ; then
            LogPrint "Not adding '$new_kernel_option' (persistent network interface naming is used)"
            continue
        fi
    fi
    LogPrint "Adding '$new_kernel_option' to KERNEL_CMDLINE"
    KERNEL_CMDLINE+=" $new_kernel_option"
done

# The user may hav added 'net.ifnames=0' to KERNEL_CMDLINE in /etc/rear/local.conf
# but he does not know whether or not persistent naming is used.
# So we should protect the rescue/recovery system from doing "stupid things"
# and remove 'net.ifnames=0' in a preventive way when persistent naming is used:
if is_true $persistent_naming ; then
    if echo $KERNEL_CMDLINE | grep -q 'net.ifnames=0' ; then
        KERNEL_CMDLINE=$( echo $KERNEL_CMDLINE | sed -e 's/net.ifnames=0//' )
        LogPrint "Removed 'net.ifnames=0' from KERNEL_CMDLINE (persistent network interface naming is used)"
    fi
fi
