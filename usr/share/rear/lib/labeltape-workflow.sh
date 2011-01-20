# labeltape-workflow.sh
#

WORKFLOW_labeltape_DESCRIPTION="Label tape for OBDR use in ReaR."
WORKFLOWS=( ${WORKFLOWS[@]} labeltape )
WORKFLOW_labeltape () {
	for arg in "${ARGS[@]}" ; do
		key=OPT_"${arg%%=*}"
		val="${arg#*=}"
		declare $key="$val"
		Log "Setting $key=$val"
	done

	SourceStage "label/tape"

	SourceStage "cleanup"

}
