# mkbackup-workflow.sh
#

WORKFLOW_mkbackuponly_DESCRIPTION="backup system without creating rescue media"
WORKFLOWS=( ${WORKFLOWS[@]} mkbackuponly )
WORKFLOW_mkbackuponly () {

	SourceStage "prep"

	DISKLAYOUT_FILE=$TMP_DIR/backuplayout.conf
	SourceStage "layout/save"

	SourceStage "backup"
}
