
# mkbackup-workflow.sh
#

WORKFLOW_mkbackuponly_DESCRIPTION="backup system without creating rescue media"
WORKFLOWS+=( mkbackuponly )

function WORKFLOW_mkbackuponly () {

    SourceStage "prep"

    # Let mkbackuponly use the same excludes as the layout code:
    DISKLAYOUT_FILE=$TMP_DIR/backuplayout.conf
    SourceStage "layout/save"

    SourceStage "backup"
}

