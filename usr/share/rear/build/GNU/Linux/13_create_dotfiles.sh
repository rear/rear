# 20_create_dotfiles.sh
#
# Create some . dot files for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# create a simple bash history file, use this ruler to make sure that
# the comments stay in a single line :-)
#-------------------------------------------------------80-|
cat <<EOF > $ROOTFS_DIR/root/.bash_history
: : : : : WHAT ELSE WOULD YOU HAVE EXPECTED HERE?
vi /var/lib/rear/layout/diskrestore.sh   # View/modify disk restore script
vi /var/lib/rear/layout/disklayout.conf  # View/modify disk layout configuration
less $LOGFILE   # View log file
loadkeys -d     # Load default keyboard layout (US)
rear recover    # Recover your system
EOF
chmod $v 0644 $ROOTFS_DIR/root/.bash_history >&2

# any other dot files should be listed below
