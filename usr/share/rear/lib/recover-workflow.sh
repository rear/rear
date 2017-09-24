# recover-workflow.sh
#
# recover workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

WORKFLOW_recover_DESCRIPTION="recover the system"
WORKFLOWS=( ${WORKFLOWS[@]} recover )
function WORKFLOW_recover () {
    # Adapt /etc/motd in the ReaR recovery system when 'rear recover' is running
    # to avoid the additional 'Run "rear recover" to restore your system !' message
    # that only makes sense as long as 'rear recover' was not ever started, see
    # https://github.com/rear/rear/issues/1433
    test -w /etc/motd && echo -e '\nWelcome to Relax-and-Recover.\n' >/etc/motd

    SourceStage "setup"

    SourceStage "verify"

    SourceStage "layout/prepare"
    SourceStage "layout/recreate"

    SourceStage "restore"

    SourceStage "finalize"
    SourceStage "wrapup"
}

