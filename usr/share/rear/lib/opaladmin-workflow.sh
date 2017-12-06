#
# opaladmin-workflow.sh
#

WORKFLOW_opaladmin_DESCRIPTION="administrate TCG Opal 2-compliant self-encrypting disks"
WORKFLOWS+=( opaladmin )

function opaladmin_usage_error() {
    # prints usage information, then exits.

    Error "Use '$PROGRAM opaladmin help' for more information."
}

function opaladmin_help() {
    # prints a help message.

    LogPrintError "Usage: $PROGRAM opaladmin ACTION [-- OPTIONS] [DEVICE ...]"
    LogPrintError "  Administrate TCG Opal 2-compliant self-encrypting disks"
    LogPrintError ""
    LogPrintError "Options:"
    LogPrintError "  -I FILE, --image=FILE   use FILE as the PBA image (default: auto-detect)"
    LogPrintError "(Unfortunately, options must be prefixed by '--'.)"
    LogPrintError ""
    LogPrintError "Actions:"
    LogPrintError "  info           print locking information"
    LogPrintError "  setupERASE     enable locking and assign a disk password, ERASING ALL DATA ON THE DISK(S)"
    LogPrintError "                 (requires one or more DEVICE arguments, or 'ALL' for all available disks)"
    LogPrintError "  changePW       change the disk password"
    LogPrintError "  uploadPBA      upload the PBA image to boot disk(s) (whose shadow MBR is enabled)"
    LogPrintError "  unlock         unlock disk(s)"
    LogPrintError "  resetDEK       assign a new data encryption key, ERASING ALL DATA ON THE DISK(S)"
    LogPrintError "                 (requires one or more DEVICE arguments, or 'ALL' for all available disks)"
    LogPrintError "  factoryRESET   reset disk(s) to factory defaults, ERASING ALL DATA ON THE DISK(S)"
    LogPrintError "                 (requires one or more DEVICE arguments, or 'ALL' for all available disks)"
    LogPrintError "  help           print this help message and exit"
    LogPrintError ""
    LogPrintError "If multiple Opal 2-compliant disks are available and no DEVICE argument is present,"
    LogPrintError "actions are performed on all available disks."
}

function WORKFLOW_opaladmin() {
    # ReaR command 'opaladmin'

    [[ -n "$DEBUGSCRIPTS" ]] && set -$DEBUGSCRIPTS_ARGUMENT

    Log "Command line options of the opaladmin workflow: $*"

    if (($# < 1)); then
        PrintError "Missing required ACTION argument."
        opaladmin_usage_error
    fi

    # Parse action argument
    local action

    case "$1" in
        (info|changePW|uploadPBA|unlock)
            action="$1"
            shift
            ;;
        (setupERASE|resetDEK|factoryRESET)
            action="$1"
            shift
            if (($# < 1)); then
                PrintError "Missing required DEVICE argument for action \"$action\"."
                opaladmin_usage_error
            fi
            ;;
        (help)
            opaladmin_help
            return 0
            ;;
        ("")
            PrintError "Missing required ACTION argument."
            opaladmin_usage_error
            ;;
        (*)
            PrintError "Unknown action \"$1\"."
            opaladmin_usage_error
            ;;
    esac

    # Parse options
    local options
    options="$(getopt -n "$PROGRAM opaladmin" -o "I:" -l "image:" -- "$@" 2>&8)"
    [[ $? != 0 ]] && opaladmin_usage_error

    eval set -- "$options"
    while true; do
        case "$1" in
            (-I|--image)
                OPALADMIN_IMAGE_FILE="$2"
                shift 2
                ;;
            (--)
                shift
                break
                ;;
            (*)
                Error "Internal error during option processing (\"$1\")."
                ;;
        esac
    done

    # Find TCG Opal 2-compliant disks
    OPALADMIN_DEVICES=( $(opal_devices) )
    (( ${#OPALADMIN_DEVICES[@]} == 0 )) && Error "Could not detect TCG Opal 2-compliant disks."

    # Device arguments on the command line override auto-detected devices
    if (($# > 0)); then
        local device
        for device; do
            if [[ "$device" == "ALL" ]]; then
                # use all available devices, check no further arguments
                set -- "${OPALADMIN_DEVICES[@]}"
                break
            elif ! IsInArray "$device" "${OPALADMIN_DEVICES[@]}"; then
                Error "Device \"$device\" could not be identified as being an Opal 2-compliant disk."
            fi
        done

        OPALADMIN_DEVICES=( "$@" )
    fi

    : ${OPALADMIN_IMAGE_FILE:="$(opal_local_pba_image_file)"}
    [[ -n "$OPALADMIN_IMAGE_FILE" ]] && opal_check_pba_image "$OPALADMIN_IMAGE_FILE"

    eval "opaladmin_${action}_action"  # do not pass arguments here due to eval

    return 0
}


#
# Action functions
# - take a list of devices as arguments, defaulting to "${OPALADMIN_DEVICES[@]}",
# - call opaladmin_get_password() before using the password "$OPALADMIN_PASSWORD",
# - use the PBA image "$OPALADMIN_IMAGE_FILE" (when empty: there is no PBA image).
#

function opaladmin_info_action() {
    local devices=( "${@:-${OPALADMIN_DEVICES[@]}}" )
    # prints locking information.

    LogUserOutput "$(opal_device_information "${devices[@]}")"
}

function opaladmin_setupERASE_action() {
    local devices=( "${@:-${OPALADMIN_DEVICES[@]}}" )
    # enables locking, assigns a disk password and resets the DEK, ERASING ALL DATA ON THE DISK.

    local device
    local -i device_number=1

    if [[ -z "$OPALADMIN_IMAGE_FILE" ]]; then
        LogUserOutput "Could not find a PBA image file."
        local prompt="Continue setup without boot disk support (y/n)? "
        local confirmation="$(opaladmin_choice_input "OPALADMIN_SETUP_NO_BOOT_SUPPORT" "$prompt" "y" "n")"
        [[ "$confirmation" == "y" ]] || Error "Setup aborted."
    fi

    for device in "${devices[@]}"; do
        source "$(opal_device_attributes "$device" attributes)"

        LogUserOutput ""

        if [[ "${attributes[support]}" == "n" ]]; then
            LogUserOutput "SKIPPING: Device $(opal_device_identification "$device") does not support locking - skipping setup."
        else
            if [[ "${attributes[setup]}" == "y" ]]; then
                LogUserOutput "Opal locking on device $(opal_device_identification "$device") has already been enabled."

                opaladmin_device_unlock_if_locked "$device" "\"$device\""
            else
                LogUserOutput "Setting up Opal locking on device $(opal_device_identification "$device")..."

                local enable_boot_unlocking="n"

                if [[ -n "$OPALADMIN_IMAGE_FILE" ]]; then
                    local prompt="Shall device \"$device\" act as a boot device for disk unlocking (y/n)? "
                    enable_boot_unlocking="$(opaladmin_choice_input "OPALADMIN_SETUP_BOOT_$device_number" "$prompt" "y" "n")"
                fi

                if [[ -z "$OPALADMIN_PASSWORD" ]]; then
                    # If this is the first time a password is being entered, check twice.
                    OPALADMIN_PASSWORD="$(opaladmin_checked_password_input "OPALADMIN_PASSWORD" "disk password")"
                fi

                opal_device_setup "$device" "$OPALADMIN_PASSWORD"
                StopIfError "Could not set up device \"$device\"."
                LogUserOutput "Initial setup successful."

                if [[ "$enable_boot_unlocking" == "y" ]]; then
                    opaladmin_use_image_file
                    LogUserOutput "Enabling shadow MBR and uploading the PBA to device \"$device\"..."
                    opal_device_enable_mbr "$device" "$OPALADMIN_PASSWORD"
                    StopIfError "Could not enable the shadow MBR on device \"$device\"."
                    opal_device_load_pba_image "$device" "$OPALADMIN_PASSWORD" "$OPALADMIN_IMAGE_FILE"
                    StopIfError "Could not upload the PBA image to device \"$device\"."
                    LogUserOutput "Shadow MBR enabled and PBA uploaded."
                else
                    opal_device_disable_mbr "$device" "$OPALADMIN_PASSWORD"
                    LogUserOutput "Shadow MBR disabled."
                fi
            fi

            opaladmin_resetDEK_action "$device"
        fi

        device_number+=1
    done
}

function opaladmin_changePW_action() {
    local devices=( "${@:-${OPALADMIN_DEVICES[@]}}" )
    # changes the disk password.

    local new_password device try_count

    new_password="$(opaladmin_checked_password_input "OPALADMIN_NEW_PASSWORD" "new disk password")"

    for device in "${devices[@]}"; do
        LogUserOutput ""

        if [[ "$(opal_device_attribute "$device" "setup")" == "y" ]]; then
            LogUserOutput "Changing disk password of device $(opal_device_identification "$device")..."

            for try_count in $(seq 3); do
                opaladmin_get_password "old password"
                if opal_device_change_password "$device" "$OPALADMIN_PASSWORD" "$new_password"; then
                    LogUserOutput "Password changed."
                    break 2
                else
                    OPALADMIN_PASSWORD=""  # Assume that the password for this disk did not fit, retry with a new one
                    PrintError "Could not change password."
                fi
            done
            PrintError "Changing disk password of device \"$device\" unsuccessful."
        else
            LogUserOutput "SKIPPING: Device $(opal_device_identification "$device") has not been setup, cannot change password."
        fi
    done

    OPALADMIN_PASSWORD="$new_password"
}

function opaladmin_uploadPBA_action() {
    local devices=( "${@:-${OPALADMIN_DEVICES[@]}}" )
    # uploads the PBA image on disk(s) whose shadow MBR is enabled.

    local device

    for device in "${devices[@]}"; do
        LogUserOutput ""

        if [[ "$(opal_device_attribute "$device" "setup")" == "y" ]]; then
            if opal_device_mbr_is_enabled "$device"; then
                opaladmin_use_image_file
                LogUserOutput "Uploading the PBA to device $(opal_device_identification "$device")..."
                opaladmin_get_password
                opal_device_load_pba_image "$device" "$OPALADMIN_PASSWORD" "$OPALADMIN_IMAGE_FILE"
                StopIfError "Could not upload the PBA image to device \"$device\"."
                LogUserOutput "PBA uploaded."
            else
                LogUserOutput "Device $(opal_device_identification "$device") is not a boot device, skipping PBA upload."
            fi
        else
            LogUserOutput "SKIPPING: Device $(opal_device_identification "$device") has not been setup, cannot upload PBA."
        fi
    done
}

function opaladmin_unlock_action() {
    local devices=( "${@:-${OPALADMIN_DEVICES[@]}}" )
    # unlocks disk(s).

    local device

    for device in "${devices[@]}"; do
        LogUserOutput ""

        if [[ "$(opal_device_attribute "$device" "setup")" == "y" ]]; then
            if [[ "$(opal_device_attribute "$device" "locked")" == "y" ]]; then
                opaladmin_device_unlock_if_locked "$device" "$(opal_device_identification "$device")"
            else
                LogUserOutput "Device $(opal_device_identification "$device") is already unlocked."
            fi
        else
            LogUserOutput "SKIPPING: Device $(opal_device_identification "$device") has not been setup, cannot unlock."
        fi
    done
}

function opaladmin_resetDEK_action() {
    local devices=( "${@:-${OPALADMIN_DEVICES[@]}}" )
    # assigns a new data encryption key, ERASING ALL DATA ON THE DISK.

    local device

    for device in "${devices[@]}"; do
        LogUserOutput ""

        if [[ "$(opal_device_attribute "$device" "setup")" == "y" ]]; then
            # Unlock before checking device contents
            opaladmin_device_unlock_if_locked "$device" "$(opal_device_identification "$device")"

            local confirmation="$(opaladmin_erase_confirmation "$device" "Reset data encryption key (DEK) of device \"$device\"")"

            if [[ "$confirmation" == "YesERASE" ]]; then
                LogUserOutput "About to reset the data encryption key (DEK) of device $(opal_device_identification "$device")..."
                opaladmin_get_password
                opal_device_regenerate_dek_ERASING_ALL_DATA "$device" "$OPALADMIN_PASSWORD"
                if (( $? == 0 )); then
                    LogUserOutput "Data encryption key (DEK) reset, data erased."
                else
                    LogUserOutput "WARNING: Could not reset data encryption key (DEK) of device \"$device\"."
                fi
            else
                LogUserOutput "SKIPPING: Data encryption key (DEK) of device $(opal_device_identification "$device") left untouched."
            fi
        else
            LogUserOutput "SKIPPING: Device $(opal_device_identification "$device") has not been setup, data encryption key (DEK) left untouched."
        fi
    done
}

function opaladmin_factoryRESET_action() {
    local devices=( "${@:-${OPALADMIN_DEVICES[@]}}" )
    # resets disks to factory defaults, ERASING ALL DATA ON THE DISK.

    local device

    for device in "${devices[@]}"; do
        LogUserOutput ""

        if [[ "$(opal_device_attribute "$device" "setup")" == "y" ]]; then
            # Unlock before checking device contents
            opaladmin_device_unlock_if_locked "$device" "$(opal_device_identification "$device")"

            local confirmation="$(opaladmin_erase_confirmation "$device" "Factory-reset device \"$device\"")"

            if [[ "$confirmation" == "YesERASE" ]]; then
                LogUserOutput "About to reset device $(opal_device_identification "$device") to factory defaults..."
                opaladmin_get_password
                opal_device_factory_reset_ERASING_ALL_DATA "$device" "$OPALADMIN_PASSWORD"
                StopIfError "Could not reset device \"$device\" to factory defaults."
                LogUserOutput "Device reset to factory defaults, data erased."
            else
                LogUserOutput "SKIPPING: Device $(opal_device_identification "$device") left untouched."
            fi
        else
            LogUserOutput "SKIPPING: Device $(opal_device_identification "$device") has not been setup, left untouched."
        fi
    done
}

function opaladmin_device_unlock_if_locked() {
    local device="${1:-?}"
    local identification="${2:-?}"
    # unlocks the device if necessary.

    if [[ "$(opal_device_attribute "$device" "locked")" == "y" ]]; then
        LogUserOutput "Unlocking device $identification..."
        opaladmin_get_password
        opal_device_unlock "$device" "$OPALADMIN_PASSWORD"
        StopIfError "Could not unlock device \"$device\"."
        LogUserOutput "Device unlocked."
    fi
}

function opaladmin_get_password() {
    local which="${1:-disk password}"
    # sets $OPALADMIN_PASSWORD, asking the user if not already done.

    if [[ -z "$OPALADMIN_PASSWORD" ]]; then
        OPALADMIN_PASSWORD="$(opaladmin_password_input "OPALADMIN_PASSWORD" "Enter $which: ")"
    fi
}

function opaladmin_password_input() {
    local id="${1:?}"
    local prompt="${2:?}"
    # prints secret user input after verifying that it is non-empty.

    local password

    while true; do
        password="$(UserInput -I "$id" -C -r -s -t 0 -p "$prompt")"
        [[ -n "$password" ]] && break
        PrintError "Please enter a non-empty password."
    done

    UserOutput ""
    echo "$password"
}

function opaladmin_checked_password_input() {
    local id="${1:?}"
    local password_name="${2:?}"
    # prints secret user input after verifying that it is non-empty and it has been entered identically twice.

    local password

    while true; do
        password="$(opaladmin_password_input "$id" "Enter $password_name: ")"
        local password_repeated="$(opaladmin_password_input "$id" "Repeat $password_name: ")"

        [[ "$password_repeated" == "$password" ]] && break

        PrintError "Passwords do not match."
    done

    echo "$password"
}

function opaladmin_choice_input() {
    local id="${1:?}"
    local prompt="${2:?}"
    shift 2
    local choices=( "$@" )
    # prints user input after verifying that it complies with one of the choices specified.

    while true; do
        result="$(UserInput -I "$id" -t 0 -p "$prompt")"
        IsInArray "$result" "${choices[@]}" && break
    done

    echo "$result"
}

function opaladmin_erase_confirmation() {
    local device="${1:?}"
    local prompt="${2:?}, ERASING ALL DATA (YesERASE/No)? "
    # sets $OPALADMIN_PASSWORD, asking the user if not already done.

    local confirmation="No"

    [[ "$(opal_device_attribute "$device" "locked")" == "n" ]] || BugError "Cannot safety-check contents of locked device \"$device\""

    if opal_disk_has_partitions "$device"; then
        if opal_disk_has_mounted_partitions "$device"; then
            LogUserOutput "Device $(opal_device_identification "$device") contains mounted partitions:"
            LogUserOutput "$(opal_disk_partition_information "$device")"
        else
            LogUserOutput "Device $(opal_device_identification "$device") contains partitions:"
            LogUserOutput "$(opal_disk_partition_information "$device")"
            confirmation="$(opaladmin_choice_input "OPALADMIN_ERASE_CONFIRM" "$prompt" "YesERASE" "No")"
        fi
    else
        confirmation="YesERASE"
    fi

    echo "$confirmation"
}

function opaladmin_use_image_file() {
    # ensures that $OPALADMIN_IMAGE_FILE is non-empty or exits with an error.

    [[ -n "$OPALADMIN_IMAGE_FILE" ]] || Error "Could not find a PBA image file."
    LogPrint "Using PBA image file \"$OPALADMIN_IMAGE_FILE\"."
}
