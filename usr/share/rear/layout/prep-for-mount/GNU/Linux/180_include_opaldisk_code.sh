# Code to recreate TCG Opal 2-compliant self-encrypting disks

function create_opaldisk_continue_unencrypted() {
    local error_message="${1:-?}"
    local device="${2:-?}"
    # prints message, stops with an error unless user confirms to continue.

    LogPrintError "$error_message"

    prompt="Continue without disk encryption on $device (y/n) ?"
    if [[ "$(opal_choice_input "OPAL_OPALDISK_CREATE_UNENCRYPTED" "$prompt" "y" "n")" == "y" ]]; then
        echo "LogPrint \"Skipping opaldisk:$device: $error_message\"" >> "$LAYOUT_CODE"
    else
        Error "Confirmation denied. Aborting."
    fi
}

function create_opaldisk() {
    local device=${1#opaldisk:}
    # recreates a component opaldisk:<device>

    local opaldisk options
    read opaldisk device options < <(grep "^opaldisk $device " "$LAYOUT_FILE")

    local boot="" password="" pba_image_file=""

    local option key value
    for option in $options; do
        key="${option%=*}"
        value="${option#*=}"

        case "$key" in
            boot)
                boot="$value"
                : ${pba_image_file:="$(opal_local_pba_image_file)"}
                [[ -n "$pba_image_file" ]] || Error "Could not find a PBA image for self-encrypting Opal 2 boot disk $device."
                ;;
            password)
                password="$value"
                ;;
        esac
    done

    local devices=( $(opal_devices) )
    if ! IsInArray "$device" "${devices[@]}"; then
        create_opaldisk_continue_unencrypted "Device $device is not a TCG Opal 2-compliant self-encrypting disk." "$device"
        return 0
    fi
    if [[ "$(opal_device_attribute "$device" "support")" == "n" ]]; then
        create_opaldisk_continue_unencrypted "Device $(opal_device_identification "$device") does not support locking." "$device"
        return 0
    fi

    {
        echo "# Protect against passwords appearing in the log file"
        echo "{ opaldisk_caller_bash_set_options=\"\$-\"; set +x; } 2>/dev/null"  # silently turn off '-x' but remember its state

        echo "LogPrint \"Setting up TCG Opal 2 self-encrypting disk $device\""

        if [[ -n "$password" ]]; then
            echo "opaldisk_password='$password'"
        else
            local prompt="password for self-encrypting disk $device"
            echo "# Re-use OPAL_DISK_PASSWORD if multiple self-encrypting disks are present"
            echo ": \${OPAL_DISK_PASSWORD:=\"\$(opal_checked_password_input \"OPAL_DISK_PASSWORD\" \"$prompt\")\"}"
            echo "opaldisk_password=\"\$OPAL_DISK_PASSWORD\""
        fi

        echo "opal_device_recreate_setup \"$device\" \"\$opaldisk_password\""

        if [[ "$boot" == "y" ]]; then
            echo "opal_device_recreate_boot_support \"$device\" \"\$opaldisk_password\" \"$pba_image_file\""
        fi

        echo "[[ \"\$opaldisk_caller_bash_set_options\" == *x* ]] && set -x"  # restore '-x' to previous state
        echo ""
    } >> "$LAYOUT_CODE"
}
