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
# the user has to do the main part here :-)
#
#

LogPrint "Please restore your backup in the provided shell to /mnt/local and, when finished, type exit
in the shell to continue recovery. You can use duplicity / duply to restore your backup."

export TMPDIR=/mnt/local
rear_shell "Did you restore the backup to /mnt/local ? Are you ready to continue recovery ?"
