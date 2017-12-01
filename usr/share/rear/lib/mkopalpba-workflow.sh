# Workflow for TCG Opal pre-boot authentication (PBA) image creation
#

WORKFLOW_mkopalpba_DESCRIPTION="create a TCG Opal pre-boot authentication (PBA) image"
WORKFLOWS+=( mkopalpba )

function WORKFLOW_mkopalpba() {
    BACKUP=OPALPBA  # Makes ReaR create a minimal PBA system
    OUTPUT=RAWDISK  # A raw disk image is the only valid output for this workflow

	SourceStage "prep"

	SourceStage "rescue"

	SourceStage "build"

	SourceStage "pack"

	SourceStage "output"
}
