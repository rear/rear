# usage-workflow.sh
#
# mkrescue workflow for Relax & Recover
#
#    Relax & Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax & Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax & Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

LOCKLESS_WORKFLOWS=( ${LOCKLESS_WORKFLOWS[@]} help )
WORKFLOW_help () {
	cat <<EOF
$SCRIPT_FILE [Options] <command> [command options ...]
$COPYRIGHT
$PRODUCT comes with ABSOLUTELY NO WARRANTY; for details 
see the GNU General Public License at http://www.gnu.org/licenses/gpl.html

Available Options:
-V                      version information
-v                      verbose mode
-d                      debug mode
-D                      debugscript mode
-S                      Step-by-step mode
-s                      Simulation mode (shows the scripts included)
-q                      Quiet mode
-r a.b.c-xx-yy          kernel version to use (current: '"$KERNEL_VERSION"')

List of commands:
$(
for w in ${WORKFLOWS[@]} ; do
	        description=WORKFLOW_${w}_DESCRIPTION
		        test "${!description}" && printf "%-24s%s\n" $w "${!description}"
		done
)

The $PRODUCT logfile is $LOGFILE
EOF
	EXIT_CODE=1
}
