# sane_recovery_check
#
# recover workflow for Relax & Recover
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

# sane_recovery_check purpose is abort recover process when no vital info found

# disabled by GSS because this doesn't do anything (in case that no such file is found it lists /usr/share/rear ...)
# and clobbers up the log file
#
#	ls "$VAR_DIR"/recovery/partitions.* 1>&2 || \
#		Error "No disk information - abort recovery"
#
