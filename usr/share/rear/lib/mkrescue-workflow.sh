# mkrescue-workflow.sh
#
# mkrescue workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

WORKFLOW_mkrescue_DESCRIPTION="create rescue media only"
WORKFLOWS+=( mkrescue )
WORKFLOW_mkrescue () {

	SourceStage "prep"

	SourceStage "layout/save"

	SourceStage "rescue"

	SourceStage "build"

	SourceStage "pack"

	SourceStage "output"
}
