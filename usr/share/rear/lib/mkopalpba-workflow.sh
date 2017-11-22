# Workflow for TCG Opal pre-boot authentication (PBA) image creation
#

WORKFLOW_mkopalbpa_DESCRIPTION="create a TCG Opal pre-boot authentication (PBA) image"
WORKFLOWS+=( mkopalbpa )
WORKFLOW_mkopalbpa () {
    BACKUP=OPALPBA  # Makes ReaR create a minimal PBA system
    OUTPUT=RAWDISK  # A raw disk image is the only valid output for this workflow

	SourceStage "prep"

	SourceStage "layout/save"

	SourceStage "rescue"

	SourceStage "build"

	SourceStage "pack"

	SourceStage "output"
}
