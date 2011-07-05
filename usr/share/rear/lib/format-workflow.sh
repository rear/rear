# format-workflow.sh
#

WORKFLOW_format_DESCRIPTION="format and label media for use with rear"
WORKFLOWS=( ${WORKFLOWS[@]} format )
WORKFLOW_format () {

    local DEVICE=""

    # Parse options
    OPTS="$(getopt -n "$PROGRAM format" -o "fhy" -l "force,help,yes" -- "$@")"
    if (( $? != 0 )); then
        echo "Try \`$PROGRAM format -- --help' for more information."
        exit 1
    fi

    eval set -- "$OPTS"
    while true; do
        case "$1" in
            (-f|--force) FORCE=y;;
            (-h|--help) echo "Valid options are: -f/--force or -y/--yes"; exit 1;;
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

    if [[ -z "$DEVICE" ]]; then
        Error "No device provided as argument."
    elif [[ -c "$DEVICE" ]]; then
        OUTPUT=OBDR
    elif [[ -b "$DEVICE" ]]; then
        OUTPUT=USB
    else
        Error "Device $DEVICE is not a character, nor a block device."
    fi

    SourceStage "format"

}
