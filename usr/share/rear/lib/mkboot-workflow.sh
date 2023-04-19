# mkboot-workflow.sh
#
# mkboot workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

WORKFLOW_mkboot_DESCRIPTION="create boot media without recovery information"
WORKFLOWS+=( mkboot )
WORKFLOW_mkboot () {

	SourceStage "prep"

	SourceStage "rescue"

	SourceStage "build"

	SourceStage "pack"

	SourceStage "output"
}
