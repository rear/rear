# format-workflow.sh
#

# Usage: rear -v format -- -h /dev/<usb-disk>
# By default 1 partition will be created with ext3 format and label REAR-000
# With the --efi toggle you get 2 partitions (vfat and ext3) so we are able
# to make this USB UEFI bootable afterwards

WORKFLOW_format_DESCRIPTION="Format and label medium for use with ReaR"
WORKFLOWS=( ${WORKFLOWS[@]} format )
WORKFLOW_format () {

    local DEVICE=""

    # Parse options
    # (do not use OPTS here because that is readonly in the rear main script):
    format_workflow_opts="$(getopt -n "$PROGRAM format" -o "efhy" -l "efi,force,help,yes" -- "$@")"
    if (( $? != 0 )); then
        echo "Try \`$PROGRAM format -- --help' for more information."
        exit 1
    fi

    eval set -- "$format_workflow_opts"
    while true; do
        case "$1" in
            (-e|--efi) EFI=y;;
            (-f|--force) FORCE=y;;
            (-h|--help) echo "Valid options are: -e/--efi, -f/--force or -y/--yes"; exit 1;;
            (-y|--yes) YES=y;;
            (--) shift; continue;;
            ("") break;;
            (/*)
                if [[ "$DEVICE" ]]; then
                    Error "Device $DEVICE already provided, only one argument is accepted"
                else
                    DEVICE=$1
                fi;;
            (*) Error "Argument $1 is not accepted.";;
        esac
        shift
    done

    if [[ -z "$DEVICE" ]] ; then
        test "$SIMULATE" || Error "No device provided as argument."
        # Simulation mode should work even without a device specified
        # see https://github.com/rear/rear/issues/1098#issuecomment-268973536
        LogPrint "Simulation mode for the format workflow with a USB device /dev/sdX:"
        OUTPUT=USB
        SourceStage "format"
        LogPrint "Simulation mode for the format workflow with a OBDR tape device /dev/stX:"
        OUTPUT=OBDR
        SourceStage "format"
        return 0
    fi

    if [[ -c "$DEVICE" ]]; then
        OUTPUT=OBDR
    elif [[ -b "$DEVICE" ]]; then
        OUTPUT=USB
    else
        Error "Device $DEVICE is neither a character, nor a block device."
    fi

    SourceStage "format"

}

