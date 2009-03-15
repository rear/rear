# mkbackup-workflow.sh
#

WORKFLOW_mkbackuponly_DESCRIPTION="Backup system without creating a (new) rescue media."
WORKFLOWS=( ${WORKFLOWS[@]} mkbackuponly )
WORKFLOW_mkbackuponly () {
	for arg in "${ARGS[@]}" ; do
		key=OPT_"${arg%%=*}"
		val="${arg#*=}"
		declare $key="$val"
		Log "Setting $key=$val"
	done

	SourceStage "prep"
	
	#SourceStage "dr"
	
	#SourceStage "rescue"
	
	#SourceStage "build"
	
	#SourceStage "pack"
	
	SourceStage "backup"
	
	#SourceStage "output"
	
	SourceStage "cleanup"
	
}
