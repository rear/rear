# mkbackup-workflow.sh
#

WORKFLOW_mkbackuponly_DESCRIPTION="backup system without creating rescue media"
WORKFLOWS=( ${WORKFLOWS[@]} mkbackuponly )
WORKFLOW_mkbackuponly () {
	for arg in "${ARGS[@]}" ; do
		key=OPT_"${arg%%=*}"
		val="${arg#*=}"
		declare $key="$val"
		Log "Setting $key=$val"
	done

	SourceStage "prep"

	DISKLAYOUT_FILE=$TMP_DIR/backuplayout.conf
	SourceStage "layout/save"

	SourceStage "backup"
}
