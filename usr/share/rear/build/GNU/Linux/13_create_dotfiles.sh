# 20_create_dotfiles.sh
#
# Create some . dot files for Relax & Recover
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

# create a simple bash history file, use this ruler to make sure that
# the comments stay in a single line :-)
#---------------------------------------------------------------------------80-|
cat <<EOF > $ROOTFS_DIR/.bash_history
less $LOGFILE            # view ReaR's log file
loadkeys -d              # load a default keyboard layout (usually US)
rear recover             # recovery your system
EOF
chmod 0644 $ROOTFS_DIR/.bash_history
ln -sf ../.bash_history $ROOTFS_DIR/root/.bash_history

# any other dot files should be listed below
