# Describe TCG Opal 2-compliant self-encrypting disks

has_binary sedutil-cli || return 0

local devices=( $(opal_devices) )

for device in "${devices[@]}"; do
    source "$(opal_device_attributes "$device" attributes)"

    [[ "${attributes[setup]}" == "y" ]] || continue

    if [[ "${attributes[locked]}" == "y" ]]; then
        LogPrintError "TCG Opal 2 self-encrypting disk \"$device\" is locked: excluding from layout."
        continue
    fi

    local boot_value="y"
    [[ "${attributes[mbr]}" == "disabled" ]] && boot_value="n"

    {
        echo "# TCG Opal 2-compliant self-encrypting disk $(opal_device_identification "$device")"
        echo "# Format: opaldisk <device> [boot=<[yn]>] [password=<password>]"
        echo "opaldisk $device boot=$boot_value"
    } >> "$DISKLAYOUT_FILE"
done
