# checklayout-workflow.sh
#
# checklayout workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

WORKFLOW_checklayout_DESCRIPTION="check if the disk layout has changed"
WORKFLOWS=( ${WORKFLOWS[@]} checklayout )
LOCKLESS_WORKFLOWS=( ${LOCKLESS_WORKFLOWS[@]} checklayout )
function WORKFLOW_checklayout () {
    ORIG_LAYOUT=$VAR_DIR/layout/disklayout.conf
    TEMP_LAYOUT=$TMP_DIR/checklayout.conf

    SourceStage "layout/precompare"

    DISKLAYOUT_FILE=$TEMP_LAYOUT
    SourceStage "layout/save"

    SourceStage "layout/compare"
}
