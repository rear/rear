# format-workflow.sh
#

WORKFLOW_format_DESCRIPTION="format and label media for use with rear"
WORKFLOWS=( ${WORKFLOWS[@]} format )
WORKFLOW_format () {

	local DEVICE=""

	while (( $# > 0 )); do
		case "$1" in
			(-f|--force) FORCE=y;;
			(-y|--yes) YES=y;;
			(-h|--help) Print "Valid options are: -f/--force or -y/--yes"; exit 0;;
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
		Error "Device $DEVICE is not a character, not a block device."
	fi

	SourceStage "format"

}
