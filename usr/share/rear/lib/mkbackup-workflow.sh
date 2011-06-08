# mkbackup-workflow.sh
#

WORKFLOW_mkbackup_DESCRIPTION="create rescue media and backup system"
WORKFLOWS=( ${WORKFLOWS[@]} mkbackup )
WORKFLOW_mkbackup () {
	for arg in "${ARGS[@]}" ; do
		key=OPT_"${arg%%=*}"
		val="${arg#*=}"
		declare $key="$val"
		Log "Setting $key=$val"
	done

	SourceStage "prep"
	
	if [[ -z "$USE_LAYOUT" ]]; then
		SourceStage "dr"
	fi
	
	SourceStage "layout/save"
	
	SourceStage "rescue"
	
	SourceStage "build"
	
	SourceStage "pack"
	
	SourceStage "output"

	SourceStage "backup"
		
	SourceStage "cleanup"
	
}
