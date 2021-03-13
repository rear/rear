# finalizeonly-workflow.sh
#
# finalizeonly workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

test "$VERBOSE" && WORKFLOW_finalizeonly_DESCRIPTION="only finalize the recovery (does not yet work)"
WORKFLOWS+=( finalizeonly )
# The finalizeonly workflow is a part (a strict subset) of the recover workflow
# by skipping those part of the recover workflow that are not needed
# when the task is to only finalize the recovery (and nothing else).
# The finalizeonly workflow does currently not yet work,
# see https://github.com/rear/rear/pull/1091#issuecomment-263621714
function WORKFLOW_finalizeonly () {
    # Do nothing in simulation mode, cf. https://github.com/rear/rear/issues/1939
    if is_true "$SIMULATE" ; then
        LogPrint "${BASH_SOURCE[0]} only finalizes the recovery (does not yet work)"
        return 0
    fi
    Error "The finalizeonly workflow does not yet work: Aborting in ${BASH_SOURCE[0]}"
    SourceStage "setup"
    SourceStage "verify"
    SourceStage "layout/prepare"
    # SourceStage "layout/recreate"
    # SourceStage "restore"
    SourceStage "finalize"
    SourceStage "wrapup"
}

