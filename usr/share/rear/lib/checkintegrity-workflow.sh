# checkintegrity-workflow.sh
#
# checkintegrity workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

WORKFLOW_checkintegrity_DESCRIPTION="check files consistency"
WORKFLOWS+=( checkintegrity )
WORKFLOW_checkintegrity () {
    SourceStage "checkintegrity"
}
