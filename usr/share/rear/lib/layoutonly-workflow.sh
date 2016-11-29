# layoutonly-workflow.sh
#
# layoutonly workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

WORKFLOW_layoutonly_DESCRIPTION="recreate only the disk layout"
WORKFLOWS=( ${WORKFLOWS[@]} layoutonly )
function WORKFLOW_layoutonly () {
    SourceStage "setup"
    # SourceStage "verify"
    SourceStage "layout/prepare"
    SourceStage "layout/recreate"
    # SourceStage "restore"
    # SourceStage "finalize"
    SourceStage "wrapup"
}

