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

REQUIRED_PROGS=(
"${REQUIRED_PROGS[@]}"
gpg
duplicity
python2.6
)

PROGS=(
"${PROGS[@]}"
duply
)

COPY_AS_IS=(
"${COPY_AS_IS[@]}"
/etc/duply
/etc/python
/etc/python2.6
/root/.duply
/root/.gnupg
/usr/lib/pymodules
/usr/lib/pyshared
/usr/lib/python2.6
/usr/lib/python3.1
/usr/share/pycentral-data
/usr/share/pyshared
/usr/share/pyshared-data
/usr/share/python
/usr/share/python-apt
/usr/share/python-support
/var/lib/pycentral
)

LIBS=(
"${LIBS[@]}"
/usr/lib/librsync.so.1.0.2
/usr/lib/cruft
)
