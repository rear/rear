#
# 130_create_dotfiles.sh
#
# Create some . dot files for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Create bash history file or append to an existing one:
Log "Creating or appending to $ROOTFS_DIR/$ROOT_HOME_DIR/.bash_history"
# Use get_path to check if nano and vi are available on the original system
# (and redirect its stdout to stderr to not get its stdout in .bash_history)
# because get_path is also used in build/GNU/Linux/390_copy_binaries_libraries.sh
# where nano and vi may get coiped via PROGS into the ReaR recovery system,
# cf. https://github.com/rear/rear/issues/3151#issuecomment-1941544530
# and see https://github.com/rear/rear/pull/1306 regarding nano
# and https://github.com/rear/rear/issues/1298 when vi is not available.
# Use the |--...--| ruler below so entries fit in a 80 characters line
# so that it looks OK even on a console with 80 characters per line.
# The ReaR recovery system bash prompt is: 'RESCUE $HOSTNAME:~ # '
# that has about 21 characters (depending on $HOSTNAME length)
# so about 59 characters are left to show bash history entries
#        |-----------------------------------------------------------|
{   echo ": # no more predefined ReaR entries in the bash history"
    echo "systemctl start sshd.service              # start SSH"
    echo "ip -4 addr                                # IPv4 address"
    echo "dhcpcd eth0                               # start DHCP"
 if get_path nano 1>&2 ; then
    echo "nano /var/lib/rear/layout/diskrestore.sh  # disk restore"
    echo "nano /var/lib/rear/layout/disklayout.conf # disk layout"
 fi
 if get_path vi 1>&2 ; then
    echo "vi /var/lib/rear/layout/diskrestore.sh    # disk restore"
    echo "vi /var/lib/rear/layout/disklayout.conf   # disk layout"
 fi
    echo "less /var/log/rear/*                      # log file(s)"
    echo "loadkeys -d                               # default keymap"
    echo "rear recover                              # recover system"
    echo ": # there are some predefined entries in the bash history"
} >> $ROOTFS_DIR/$ROOT_HOME_DIR/.bash_history

# Other dot files should be listed below:
