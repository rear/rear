#
# format-workflow.sh
#
# Usage: rear -v format -- -h /dev/<usb-disk>
# By default 1 partition will be created with ext3 format and label
# USB_DEVICE_FILESYSTEM_LABEL (cf. https://github.com/rear/rear/issues/1535).
# With the --efi toggle you get 2 partitions (vfat and ext3) so we are able
# to make this USB UEFI bootable afterwards.
#

WORKFLOW_format_DESCRIPTION="Format and label medium for use with ReaR"
WORKFLOWS+=( format )
WORKFLOW_format () {

    FORMAT_DEVICE=""

    # Log the options and arguments how the format workflow is actually called:
    Log "Command line options of the format workflow: $*"

    # Parse options
    # (do not use OPTS here because that is readonly in the rear main script):
    format_workflow_opts="$( getopt -n "$PROGRAM format" -o "efhy" -l "efi,force,help,yes" -- "$@" )"
    if (( $? != 0 )) ; then
        LogPrintError "Use '$PROGRAM format -- --help' for more information."
        # TODO: Use proper exit codes cf. https://github.com/rear/rear/issues/1134
        exit 1
    fi

    eval set -- "$format_workflow_opts"
    while true ; do
        case "$1" in
            (-b|--bios)
                # Note: is handled the same as if FORMAT_EFI is not set in most scripts
                FORMAT_BIOS=y
                ;;
            (-e|--efi)
                FORMAT_EFI=y
                ;;
            (-f|--force)
                FORMAT_FORCE=y
                ;;
            (-h|--help)
                LogPrintError "Use '$PROGRAM format [ -- OPTIONS ] DEVICE' like '$PROGRAM -v format -- --efi /dev/sdX'"
                LogPrintError "Valid format workflow options are: -b/--bios -e/--efi -f/--force -y/--yes"
                # No "rear format failed, check ...rear...log for details" message:
                EXIT_FAIL_MESSAGE=0
                # TODO: Use proper exit codes cf. https://github.com/rear/rear/issues/1134
                exit 1
                ;;
            (-y|--yes)
                FORMAT_YES=y
                ;;
            (--)
                shift
                continue
                ;;
            ("")
                break
                ;;
            (/*)
                test "$FORMAT_DEVICE" && Error "Device $FORMAT_DEVICE already provided, only one argument is accepted"
                FORMAT_DEVICE=$1
                ;;
            (*)
                Error "Argument '$1' not accepted. Use '$PROGRAM format -- --help' for more information."
                ;;
        esac
        shift
    done

    # if none of the format options is used then both should be set as default
    if [ -z "$FORMAT_EFI" ] && [ -z "$FORMAT_BIOS" ] ; then
        FORMAT_BIOS=y
        FORMAT_EFI=y
    fi

    if test -z "$FORMAT_DEVICE" ; then
        if is_true "$SIMULATE" ; then
            # Simulation mode should work even without a device specified
            # see https://github.com/rear/rear/issues/1098#issuecomment-268973536
            LogPrint "Simulation mode for the format workflow with a USB or disk device /dev/sdX:"
            OUTPUT=USB
            SourceStage "format"
            LogPrint "Simulation mode for the format workflow with a OBDR tape device /dev/stX:"
            OUTPUT=OBDR
            SourceStage "format"
            return 0
        else
            LogPrintError "Use '$PROGRAM format [ -- OPTIONS ] DEVICE' like '$PROGRAM -v format -- --efi /dev/sdX'"
            LogPrintError "Valid format workflow options are: -e/--efi -f/--force -y/--yes"
            LogPrintError "Use '$PROGRAM format -- --help' for more information."
            Error "No device provided as argument."
        fi
    fi

    if [[ -c "$FORMAT_DEVICE" ]] ; then
        OUTPUT=OBDR
    elif [[ -b "$FORMAT_DEVICE" ]] ; then
        OUTPUT=USB
    else
        Error "Device $FORMAT_DEVICE is neither a character, nor a block device."
    fi

    SourceStage "format"

}

