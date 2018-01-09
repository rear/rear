# Workflow for TCG Opal pre-boot authentication (PBA) image creation
#

WORKFLOW_mkopalpba_DESCRIPTION="create a pre-boot authentication (PBA) image to boot from TCG Opal 2-compliant self-encrypting disks"
WORKFLOWS+=( mkopalpba )

function WORKFLOW_mkopalpba() {

    # Change workflow components before SourceStage jumps into action:
    # This makes the 'mkopalpba' workflow work with the configuration for the 'mkrescue' workflow,
    # yet produce a different outcome (the PBA instead of the rescue image) with it own set of
    # component scripts.
    BACKUP=OPALPBA  # There is no backup inside the PBA, so abuse the BACKUP component to create the PBA
    OUTPUT=RAWDISK  # The PBA must be a raw disk image, so ignore the regular OUTPUT (which targets the rescue image)

	SourceStage "prep"

	SourceStage "rescue"

	SourceStage "build"

	SourceStage "pack"

	SourceStage "output"
}
