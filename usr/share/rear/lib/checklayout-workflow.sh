# checklayout-workflow.sh
#
# checklayout workflow for Relax-and-Recover
#
#    Relax-and-Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax-and-Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax-and-Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

WORKFLOW_checklayout_DESCRIPTION="check if the disk layout has changed"
WORKFLOWS=( ${WORKFLOWS[@]} checklayout )
LOCKLESS_WORKFLOWS=( ${LOCKLESS_WORKFLOWS[@]} checklayout )
WORKFLOW_checklayout () {
    ORIG_LAYOUT=$VAR_DIR/layout/disklayout.conf
    TEMP_LAYOUT=$TMP_DIR/checklayout.conf

    SourceStage "layout/precompare"

    DISKLAYOUT_FILE=$TEMP_LAYOUT
    SourceStage "layout/save"

    SourceStage "layout/compare"
}
