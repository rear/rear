# label-workflow.sh
#

WORKFLOW_label_DESCRIPTION="format and label media for use with rear"
WORKFLOWS=( ${WORKFLOWS[@]} label )
WORKFLOW_label () {
	for arg in "${ARGS[@]}" ; do
		key=OPT_"${arg%%=*}"
		val="${arg#*=}"
		declare $key="$val"
		Log "Setting $key=$val"
	done

	SourceStage "label/tape"
	SourceStage "label/USB"

	SourceStage "cleanup"

}
