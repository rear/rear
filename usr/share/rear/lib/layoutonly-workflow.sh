# layoutonly-workflow.sh
#
# layoutonly workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

test "$VERBOSE" && WORKFLOW_layoutonly_DESCRIPTION="only recreate the disk layout (experimental)"
WORKFLOWS+=( layoutonly )
# The layoutonly workflow is a part (a strict subset) of the recover workflow
# by skipping those part of the recover workflow that are not needed
# when the task is to only recreate the disk layout (and nothing else):
function WORKFLOW_layoutonly () {
    SourceStage "setup"
    # SourceStage "verify"
    SourceStage "layout/prepare"
    SourceStage "layout/recreate"
    # SourceStage "restore"
    # SourceStage "finalize"
    # SourceStage "wrapup"
}

