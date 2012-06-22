# savelayout-workflow.sh
#
# savelayout workflow for Relax-and-Recover
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

if [[ "$VERBOSE" ]]; then
    WORKFLOW_savelayout_DESCRIPTION="save the disk layout of the system"
fi
WORKFLOWS=( ${WORKFLOWS[@]} savelayout )
WORKFLOW_savelayout () {
    DISKLAYOUT_FILE=$VAR_DIR/layout/disklayout.conf
    SourceStage "layout/save"
}
