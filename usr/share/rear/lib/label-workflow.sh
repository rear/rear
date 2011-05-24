# label-workflow.sh
#

WORKFLOW_label_DESCRIPTION="Label tape for OBDR or USB device used in ReaR."
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
