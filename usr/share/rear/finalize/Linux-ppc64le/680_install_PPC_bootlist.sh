# THIS SCRIPT CONTAINS PPC64/PPC64LE SPECIFIC
#################################################################
# Run bootlist only in PowerVM environment
# which means not in BareMetal(PowerNV) or KVM (emulated by qemu)

# Exit if you are not running in PowerVM mode.
if grep -q "PowerNV" /proc/cpuinfo || grep -q "emulated by qemu" /proc/cpuinfo ; then
    return
fi

# Look for the PPC PReP Boot Partition.
part_list=$( awk -F ' ' '/^part / {if ($6 ~ /prep/) {print $7}}' $LAYOUT_FILE )

# All the possible boot devices
boot_list=()

for part in $part_list ; do
    LogPrint "PPC PReP Boot partition found: $part"

    # Using $LAYOUT_DEPS file to find the disk device containing the partition.
    bootdev=$(awk '$1==PART { print $NF}' PART=$part $LAYOUT_DEPS)

    # If boot device cannot be found in $LAYOUT_DEPS file,
    # then define bootdev by removing numeric number at the end of $part
    if [[ -z $bootdev ]]; then
        bootdev=`echo $part | sed -e 's/[0-9]*$//'`
    fi

    LogPrint "Boot device disk is $bootdev."

    # Test if $bootdev is a multipath device
    # If yes, get the list of path which are part of the multipath device.
    # Limit to the first 5 PATH (see #876)
    if dmsetup ls --target multipath | grep -w ${bootdev#/dev/mapper/} >/dev/null 2>&1; then
        LogPrint "Limiting bootlist to 5 entries as a maximum..."
        boot_list+=( $(dmsetup deps $bootdev -o devname | awk -F: '{gsub (" ",""); gsub("\\(","/dev/",$2) ; gsub("\\)"," ",$2) ; print $2}' | cut -d" " -f-5) )
    else
        # Single Path device found
        boot_list+=( $bootdev )
    fi
done

if [[ ${#boot_list[@]} -gt 5 ]]; then
    LogPrint "Too many entries for bootlist command, limiting to first 5 entries..."
    boot_list=( ${boot_list[@]:0:5} )
fi

if [[ ${#boot_list[@]} -gt 0 ]]; then
    LogPrint "Set LPAR bootlist to '${boot_list[*]}'"
    bootlist -m normal "${boot_list[@]}"
    LogPrintIfError "Unable to set bootlist. You will have to start in SMS to set it up manually."
fi

# vim: set et ts=4 sw=4:
