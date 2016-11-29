# finalizeonly-workflow.sh
#
# finalizeonly workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

WORKFLOW_finalizeonly_DESCRIPTION="only finalize the recovery"
WORKFLOWS=( ${WORKFLOWS[@]} finalizeonly )
function WORKFLOW_finalizeonly () {
    SourceStage "setup"
    # SourceStage "verify"
    # SourceStage "layout/prepare"
    # SourceStage "layout/recreate"
    # SourceStage "restore"
    SourceStage "finalize"
    SourceStage "wrapup"
}

