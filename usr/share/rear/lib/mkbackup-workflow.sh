# mkbackup-workflow.sh
#

WORKFLOW_mkbackup_DESCRIPTION="create rescue media and backup system"
WORKFLOWS+=( mkbackup )
WORKFLOW_mkbackup () {
	local scheme=$(url_scheme $BACKUP_URL)

	SourceStage "prep"

	SourceStage "layout/save"

	SourceStage "rescue"

	SourceStage "build"

	SourceStage "pack"
if [[ "$scheme" = "iso" ]] && [[ "$OUTPUT" = "ISO" ]]; then
# In this case, we need to give backups a chance to be integrated in the iso before the copy to OUTPUT_URL
        SourceStage "backup"

        SourceStage "output"
else
	SourceStage "output"

	SourceStage "backup"
fi
}
