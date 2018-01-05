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

    # In case of e.g. BACKUP_URL=file:///mybackup/ automatically exclude the matching component 'fs:/mybackup'
    # otherwise 'rear checklayout' would always detect a changed layout with BACKUP_URL=file:///...
    # because during 'rear mkrescue/mkbackup' such a component was automatically excluded this way
    # so that such a component is already disabled in the ORIG_LAYOUT file and because
    # 400_automatic_exclude_recreate.sh adds such a component to the EXCLUDE_RECREATE array
    # such a component will get also disabled in the TEMP_LAYOUT file in the "layout/save" stage
    # see https://github.com/rear/rear/issues/1658
    Source $SHARE_DIR/prep/NETFS/default/400_automatic_exclude_recreate.sh

    DISKLAYOUT_FILE=$TEMP_LAYOUT
    SourceStage "layout/save"

    SourceStage "layout/compare"
}

