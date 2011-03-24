# mkobdr-workflow.sh
#

WORKFLOW_mkobdr_DESCRIPTION="Create rescue media and backup system on a bootable tape."
WORKFLOWS=( ${WORKFLOWS[@]} mkobdr )
WORKFLOW_mkobdr () {
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

	SourceStage "rescue"

	SourceStage "build"

	SourceStage "pack"
	
	SourceStage "output"

	SourceStage "backup"

	SourceStage "cleanup"

}
