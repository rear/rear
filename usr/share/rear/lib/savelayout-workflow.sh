# savelayout-workflow.sh
#
# savelayout workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

if [[ "$VERBOSE" ]]; then
    WORKFLOW_savelayout_DESCRIPTION="save the disk layout of the system"
fi
WORKFLOWS+=( savelayout )
WORKFLOW_savelayout () {
    #DISKLAYOUT_FILE=$VAR_DIR/layout/disklayout.conf # defined in default.conf now (issue #678)
    SourceStage "layout/save"
}
