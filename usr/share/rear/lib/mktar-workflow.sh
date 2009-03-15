# mktar-workflow.sh
#
# mktar workflow for Relax & Recover
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

WORKFLOW_mktar_DESCRIPTION="Create tar archive with this rear installation"
WORKFLOWS=( ${WORKFLOWS[@]} mktar )
WORKFLOW_mktar () {
	
	test "$ARGS" || Error "You must provide the filename for the archive,
	e.g. my-rear-archive.tar.gz
	The Archive will be a tar.gz archive.
	"
	
	ProgressStart "Creating archive '$ARGS'"
	tar -C / --exclude=\*~ -cvzf "$ARGS" "$SHARE_DIR" "$CONFIG_DIR" "$(which "$0")" 1>&2
	ProgressStopOrError $? "Could not create archive"
	
}
