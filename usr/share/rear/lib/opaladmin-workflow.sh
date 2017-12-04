#
# opaladmin-workflow.sh
#

WORKFLOW_opaladmin_DESCRIPTION="administrate TCG Opal 2-compliant disks"
WORKFLOWS+=( opaladmin )

function opaladmin_usage_error() {
    # prints usage information, then exits.

    Error "Use '$PROGRAM opaladmin -- --help' for more information."
}

function opaladmin_help() {
    # prints a help message.

    LogPrintError "Usage: $PROGRAM opaladmin -- [OPTIONS] ACTION [ACTION_ARGUMENT]"
    LogPrintError "  Administrate TCG Opal 2-compliant disks"
    LogPrintError ""
    LogPrintError "Options:"
    LogPrintError "  -h, --help                   print this help message and exit"
    LogPrintError "  -I FILE, --image=FILE        use FILE as the PBA image"
    LogPrintError "  -D DEVICE, --device=DEVICE   perform operations on DEVICE only"
    LogPrintError ""
    LogPrintError "Actions:"
    LogPrintError "  info                  print locking information for available disk(s)"
    LogPrintError "  setup                 enable locking on available disk(s) and assign a device password"
    LogPrintError "  changePW              change the device password on available disk(s)"
    LogPrintError "  uploadPBA             upload the PBA image to disk(s) whose shadow MBR is enabled"
    LogPrintError "  unlock                unlock available disk(s)"
    LogPrintError "  resetDEK DEVICE       assign a new data encryption key, ERASING ALL DATA ON THE DISK"
    LogPrintError "  factoryRESET DEVICE   reset the device to factory defaults, ERASING ALL DATA ON THE DISK"
    LogPrintError ""
    LogPrintError "If multiple Opal 2-compliant disks are available and DEVICE is not specified, actions are"
    LogPrintError "performed on all disks, except for PBA image installation. The latter is only performed"
    LogPrintError "on boot disks (where the shadow MBR has been enabled)."
}

function WORKFLOW_opaladmin() {
    # ReaR command 'opaladmin'

    [[ -n "$DEBUGSCRIPTS" ]] && set -$DEBUGSCRIPTS_ARGUMENT

    local device

    Log "Command line options of the opaladmin workflow: $*"

    # Parse options
    local options="$(getopt -n "$PROGRAM opaladmin" -o "hI:D:" -l "help,image:,device:" -- "$@" 2>&8)"
    [[ $? != 0 ]] && opaladmin_usage_error

    eval set -- "$options"
    while true; do
        case "$1" in
            (-h|--help)
                opaladmin_help
                return 0
                ;;
            (-I|--image)
                opaladmin_image_file="$2"
                shift 2
                ;;
            (-D|--device)
                device="$2"
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

    (($# < 1)) && Error "No action has been requested on the command line."

    local action

    case "$1" in
        (info|setup|changePW|uploadPBA|unlock)
            action="$1"
            shift
            ;;
        (resetDEK|factoryRESET)
            action="$1"
            device="$2"
            if [[ -z "$device" ]]; then
                PrintError "Required DEVICE argument missing for action \"$action\"."
                opaladmin_usage_error
            fi
            shift 2
            ;;
        ("")
            Error "No action has been requested on the command line."
            ;;
        (*)
            Error "Unknown action \"$1\"."
            ;;
    esac

    if (($# != 0)); then
        PrintError "No action has been requested on the command line."
        opaladmin_usage_error
    fi

    # Find TCG Opal 2-compliant disks
    opaladmin_devices=( $(opal_devices) )
    (( ${#opaladmin_devices[@]} == 0 )) && Error "Could not detect TCG Opal-compliant disks."

    if [[ -n "$device" ]]; then
        if IsInArray "$device" "${opaladmin_devices[@]}"; then
            opaladmin_devices=( "$device" )
        else
            Error "Device \"$device\" could not be identified as being an Opal 2-compliant disk."
        fi
    fi

    : ${opaladmin_image_file:="$(opal_local_pba_image_file)"}
    [[ -n "$opaladmin_image_file" ]] && opal_check_pba_image "$opaladmin_image_file"

    eval "opaladmin_$action"

    return 0
}

function opaladmin_info() {
    # print locking information for available disk(s).

    LogUserOutput "$(opal_device_information "${opaladmin_devices[@]}")"
}

function opaladmin_setup() {
    # enables locking on available disk(s) and assigns a device password.

    local device
    local -i device_number=1

    if [[ -z "$opaladmin_image_file" ]]; then
        LogUserOutput "Could not find a PBA image file."
        local prompt="Continue setup without boot disk support (y/n)? "
        local confirmation="$(opaladmin_choice_input "OPALADMIN_SETUP_NO_BOOT_SUPPORT" "$prompt" "y" "n")"
        [[ "$confirmation" == "y" ]] || Error "Setup aborted."
    fi

    for device in "${opaladmin_devices[@]}"; do
        source "$(opal_device_attributes "$device" attributes)"

        LogUserOutput ""

        if [[ "${attributes[support]}" == "n" ]]; then
            LogUserOutput "SKIPPING: Device $(opal_device_identification "$device") does not support locking - skipping setup."
        else
            if [[ "${attributes[setup]}" == "y" ]]; then
                LogUserOutput "SKIPPING: Opal locking on device $(opal_device_identification "$device") has already been enabled - skipping setup."

                if [[ "${attributes[locked]}" == "y" ]]; then
                    LogUserOutput "Unlocking device \"$device\"..."
                    opaladmin_get_password
                    opal_device_unlock "$device" "$opaladmin_password"
                    StopIfError "Could not unlock device \"$device\"."
                    LogUserOutput "Device unlocked."
                fi
            else
                LogUserOutput "Setting up Opal locking on device $(opal_device_identification "$device")..."

                local enable_boot_unlocking="n"

                if [[ -n "$opaladmin_image_file" ]]; then
                    local prompt="Shall device \"$device\" act as a boot device for disk unlocking (y/n)? "
                    enable_boot_unlocking="$(opaladmin_choice_input "OPALADMIN_SETUP_BOOT_$device_number" "$prompt" "y" "n")"
                fi

                if [[ -z "$opaladmin_password" ]]; then
                    # If this is the first time a password is being entered, check twice.
                    opaladmin_password="$(opaladmin_checked_password_input "OPALADMIN_PASSWORD" "disk password")"
                fi

                opal_device_setup "$device" "$opaladmin_password"
                StopIfError "Could not set up device \"$device\"."
                LogUserOutput "Setup successful."

                if [[ "$enable_boot_unlocking" == "y" ]]; then
                    opaladmin_get_image_file
                    LogUserOutput "Enabling shadow MBR and uploading the PBA to device \"$device\"..."
                    opal_device_enable_mbr "$device" "$opaladmin_password"
                    StopIfError "Could not enable the shadow MBR on device \"$device\"."
                    opal_device_load_pba_image "$device" "$opaladmin_password" "$opaladmin_image_file"
                    StopIfError "Could not upload the PBA image to device \"$device\"."
                    LogUserOutput "Shadow MBR enabled and PBA uploaded."
                else
                    opal_device_disable_mbr "$device" "$opaladmin_password"
                    LogUserOutput "Shadow MBR disabled."
                fi
            fi

            opaladmin_resetDEK "$device"
        fi

        device_number+=1
    done
}

function opaladmin_changePW() {
    # changes the device password on available disk(s).

    local new_password device try_count

    new_password="$(opaladmin_checked_password_input "OPALADMIN_NEW_PASSWORD" "new disk password")"

    for device in "${opaladmin_devices[@]}"; do
        LogUserOutput ""
        LogUserOutput "Changing disk password of device $(opal_device_identification "$device")..."

        for try_count in $(seq 3); do
            opaladmin_get_password "old password"
            if opal_device_change_password "$device" "$opaladmin_password" "$new_password"; then
                LogUserOutput "Password changed."
                break 2
            else
                opaladmin_password=""  # Assume that the password for this disk did not fit, retry with a new one
                PrintError "Could not change password."
            fi
        done
        PrintError "Changing disk password of device \"$device\" unsuccessful."
    done

    opaladmin_password="$new_password"
}

function opaladmin_uploadPBA() {
    # uploads the PBA image on disk(s) whose shadow MBR is enabled.

    local device

    for device in "${opaladmin_devices[@]}"; do
        LogUserOutput ""

        if opal_device_mbr_is_enabled "$device"; then
            opaladmin_get_image_file
            LogUserOutput "Uploading the PBA to device $(opal_device_identification "$device")..."
            opaladmin_get_password
            opal_device_load_pba_image "$device" "$opaladmin_password" "$opaladmin_image_file"
            StopIfError "Could not upload the PBA image to device \"$device\"."
            LogUserOutput "PBA uploaded."
        else
            LogUserOutput "Device $(opal_device_identification "$device") is not a boot device, skipping PBA upload."
        fi
    done
}

function opaladmin_unlock() {
    # unlocks available disk(s).

    local device

    opaladmin_get_password

    for device in "${opaladmin_devices[@]}"; do
        LogUserOutput ""
        LogUserOutput "Unlocking device $(opal_device_identification "$device")..."
        opal_device_unlock "$device" "$opaladmin_password"
        StopIfError "Could not unlock device \"$device\"."
        LogUserOutput "Device unlocked."
    done
}

function opaladmin_resetDEK() {
    local devices=( "$@" )
    # assigns a new data encryption key, ERASING ALL DATA ON THE DISK.

    (( "${#devices[@]}" == 0 )) && devices=( "${opaladmin_devices[@]}" )

    local device

    for device in "${devices[@]}"; do
        LogUserOutput ""

        local confirmation="$(opaladmin_erase_confirmation "$device" "Reset data encryption key (DEK) of device \"$device\"")"

        if [[ "$confirmation" == "YesERASE" ]]; then
            LogUserOutput "About to reset the data encryption key (DEK) of device $(opal_device_identification "$device")..."
            opaladmin_get_password
            opal_device_regenerate_dek_ERASING_ALL_DATA "$device" "$opaladmin_password"
            if (( $? == 0 )); then
                LogUserOutput "Data encryption key (DEK) reset, data erased."
            else
                LogUserOutput "WARNING: Could not reset data encryption key (DEK) of device \"$device\"."
            fi
        else
            LogUserOutput "SKIPPING: Data encryption key (DEK) of device $(opal_device_identification "$device") left untouched."
        fi
    done
}

function opaladmin_factoryRESET() {
    # resets disks to factory defaults, ERASING ALL DATA ON THE DISK.

    local device

    for device in "${opaladmin_devices[@]}"; do
        LogUserOutput ""

        local confirmation="$(opaladmin_erase_confirmation "$device" "Factory-reset device \"$device\"")"

        if [[ "$confirmation" == "YesERASE" ]]; then
            LogUserOutput "About to reset device $(opal_device_identification "$device") to factory defaults..."
            opaladmin_get_password
            opal_device_factory_reset_ERASING_ALL_DATA "$device" "$opaladmin_password"
            StopIfError "Could not reset device \"$device\" to factory defaults."
            LogUserOutput "Device reset to factory defaults, data erased."
        else
            LogUserOutput "SKIPPING: Device $(opal_device_identification "$device") left untouched."
        fi
    done
}

function opaladmin_erase_confirmation() {
    local device="${1:?}"
    local prompt="${2:?}, ERASING ALL DATA (YesERASE/No)? "
    # sets $opaladmin_password, asking the user if not already done.

    local confirmation="No"

    if opal_disk_has_partitions "$device"; then
        if opal_disk_has_mounted_partitions "$device"; then
            LogUserOutput "Device $(opal_device_identification "$device") contains mounted partitions:"
            LogUserOutput "$(opal_disk_partition_information "$device")"
        else
            LogUserOutput "Device $(opal_device_identification "$device") contains partitions:"
            LogUserOutput "$(opal_disk_partition_information "$device")"
            confirmation="$(opaladmin_choice_input "OPALADMIN_RESETDEK_CONFIRM" "$prompt" "YesERASE" "No")"
        fi
    else
        confirmation="YesERASE"
    fi

    echo "$confirmation"
}

function opaladmin_get_password() {
    local which="${1:-disk password}"
    # sets $opaladmin_password, asking the user if not already done.

    if [[ -z "$opaladmin_password" ]]; then
        opaladmin_password="$(opaladmin_password_input "OPALADMIN_PASSWORD" "Enter $which: ")"
    fi
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
        local result_repeated="$(opaladmin_password_input "$id" "Repeat $password_name: ")"

        [[ "$result_repeated" == "$password" ]] && break

        PrintError "Passwords do not match."
    done

    echo "$password"
}

function opaladmin_get_image_file() {
    # ensures that $opaladmin_image_file is the path of a local image file or exits with an error.

    [[ -n "$opaladmin_image_file" ]] || Error "Could not find a PBA image file."

    opal_check_pba_image "$opaladmin_image_file"
    LogPrint "Using PBA image file \"$opaladmin_image_file\""
}
