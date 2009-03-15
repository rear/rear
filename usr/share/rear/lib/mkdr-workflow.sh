WORKFLOWS=( ${WORKFLOWS[@]} mkdr )
WORKFLOW_mkdr () {
	for arg in "${ARGS[@]}" ; do
		key=OPT_"${arg%%=*}"
		val="${arg#*=}"
		declare $key="$val"
		Log "Setting $key=$val"
	done

	SourceStage "prep"
	
	SourceStage "dr"
	
	SourceStage "cleanup"
	
}
