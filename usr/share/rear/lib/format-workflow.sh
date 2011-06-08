# format-workflow.sh
#

WORKFLOW_format_DESCRIPTION="format and label media for use with rear"
WORKFLOWS=( ${WORKFLOWS[@]} label )
WORKFLOW_format () {
	for arg in "${ARGS[@]}" ; do
		key=OPT_"${arg%%=*}"
		val="${arg#*=}"
		declare $key="$val"
		Log "Setting $key=$val"
	done

	SourceStage "format/tape"
	SourceStage "format/USB"

	SourceStage "cleanup"

}
