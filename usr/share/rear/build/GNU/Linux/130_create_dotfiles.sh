# 200_create_dotfiles.sh
#
# Create some . dot files for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# create a simple bash history file,
# use this ruler to make sure the comments stay in a single line:
# the bash prompt is: 'RESCUE $HOSTNAME:~ #
# -----------------------------------------------------80-|
cat <<EOF > $ROOTFS_DIR/$ROOT_HOME_DIR/.bash_history
: # no more predefined ReaR entries in the bash history
systemctl start sshd.service              # start SSH daemon
ip -4 addr                                # get IPv4 address
dhcpcd eth0                               # start DHCP client
nano /var/lib/rear/layout/diskrestore.sh  # disk restore
nano /var/lib/rear/layout/disklayout.conf # disk layout
vi /var/lib/rear/layout/diskrestore.sh    # disk restore
vi /var/lib/rear/layout/disklayout.conf   # disk layout
less /var/log/rear/*                      # log file(s)
loadkeys -d                               # default keyboard
rear recover                              # recover system
: # there are some predefined entries in the bash history
EOF

chmod $v 0644 $ROOTFS_DIR/$ROOT_HOME_DIR/.bash_history >&2

# any other dot files should be listed below
