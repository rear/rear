# restoreonly-workflow.sh
#
# restoreonly workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

WORKFLOW_restoreonly_DESCRIPTION="only restore the backup"
WORKFLOWS+=( restoreonly )
# The restoreonly workflow is a part (a strict subset) of the recover workflow
# by skipping those part of the recover workflow that are not needed
# (like layout/prepare) or would be destructive (like layout/recreate)
# when the task is to only restore the backup (and nothing else):
function WORKFLOW_restoreonly () {
    SourceStage "setup"
    SourceStage "verify"
    # SourceStage "layout/prepare"
    # SourceStage "layout/recreate"
    SourceStage "restore"
    # SourceStage "finalize"
    SourceStage "wrapup"
}

