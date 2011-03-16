# mkbackup-workflow.sh
#

WORKFLOW_mkbackup_DESCRIPTION="Create rescue media and backup system."
WORKFLOWS=( ${WORKFLOWS[@]} mkbackup )
WORKFLOW_mkbackup () {
	for arg in "${ARGS[@]}" ; do
		key=OPT_"${arg%%=*}"
		val="${arg#*=}"
		declare $key="$val"
		Log "Setting $key=$val"
	done

	SourceStage "prep"
	
	SourceStage "dr"
	
	SourceStage "layout/save"
	
	SourceStage "rescue"
	
	SourceStage "build"
	
	SourceStage "pack"
	
	SourceStage "backup"
	
	SourceStage "output"
	
	SourceStage "cleanup"
	
}
