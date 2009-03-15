# #50_ssh.sh
#
# take ssh for Relax & Recover
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

if type -p sshd >/dev/null ; then

	# assume that we have openssh with configs in /etc/ssh

	COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/ssh* /root/.s[s]h /root/.shos[t]s )
	PROGS=( 
	${PROGS[@]} 
	ssh sshd scp sftp 
	$( 
		read subsys sftp file junk < <( grep sftp /etc/sshd_co[n]fig /etc/ssh/sshd_co[n]fig 2>/dev/null )
		echo $file
	)
	)

	if PASSWD_SSH=$(grep ssh /etc/passwd) ; then
	# sshd:x:71:65:SSH daemon:/var/lib/sshd:/bin/false
		echo "$PASSWD_SSH" >>$ROOTFS_DIR/etc/passwd
		IFS=: read user ex uid gid gecos homedir junk < <(echo "$PASSWD_SSH")
		mkdir -m 0700 -p "$ROOTFS_DIR$homedir"
		chown root.root "$ROOTFS_DIR$homedir"
	fi

	echo "ssh:23:respawn:/bin/sshd -D" >>$ROOTFS_DIR/etc/inittab

fi
