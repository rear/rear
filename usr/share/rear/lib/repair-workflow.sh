# recover-workflow.sh
#
# repair workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

WORKFLOW_repair_DESCRIPTION="use ReaR as live media to repair the system"
WORKFLOWS=( ${WORKFLOWS[@]} repair )
function WORKFLOW_repair () {
    # Adapt /etc/motd in the ReaR recovery system when 'rear recover' is running
    # to avoid the additional 'Run "rear recover" to restore your system !' message
    # that only makes sense as long as 'rear recover' was not ever started,
    # see https://github.com/rear/rear/issues/1433
    # but do not (over)-write /etc/motd on the original system
    # which could happen in simulation mode via 'rear -s recover'
    # that simulates sourcing scripts in the Source function
    # but this WORKFLOW_recover function call is not simulated (cf. usr/sbin/rear)
    # see https://github.com/rear/rear/issues/1670
    # and do not (over)-write /etc/motd in the recovery system in simulation mode
    # which results with the above to never (over)-write /etc/motd in simulation mode:
    if ! is_true "$SIMULATE" ; then
        # In the recovery system /etc/rear-release is unique (it does not exist otherwise)
        # cf. init/default/050_check_rear_recover_mode.sh
        test -f /etc/rear-release -a -w /etc/motd && echo -e '\nWelcome to Relax-and-Recover.\n' >/etc/motd
    fi

    SourceStage "setup"

    # 'check' stage is a minimal version of 'verify' that ignores all the
    # backup engines
    SourceStage "check"

    SourceStage "layout/prep-for-mount"
    SourceStage "layout/do-mount"

    SourceStage "wrapup"
}
