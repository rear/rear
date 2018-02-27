# prepare environment for timesync

case "$TIMESYNC" in
	NTP)
		PROGS=( "${PROGS[@]}" ntpd )
		COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/ntp.conf "/etc/ntp" )
		if [ ! -x /bin/systemctl ] ; then
			echo "NT:2345:respawn:/bin/ntpd -n -g -p /var/run/ntpd.pid" >>$ROOTFS_DIR/etc/inittab
		else
			echo "System is systemd-based, not updating $ROOTFS_DIR/etc/inittab ..."
		fi
		cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-timesync.sh <<-EOF
			echo "Setting system time via NTP ..."
			ntpd -q -g & # allow for big jumps
			ntpd_pid=\$!
			i=0
			while kill -0 \$ntpd_pid 2>/dev/null; do
				if [[ \$i -ge 10 ]]; then
					echo "Gave up on NTP after 10 seconds."
					kill \$ntpd_pid
					break
				fi
				i=\$(( \$i + 1 ))
				sleep 1
			done
		EOF
		;;
	CHRONY)
		PROGS=( "${PROGS[@]}" chronyd )
		COPY_AS_IS=( "${COPY_AS_IS[@]}" "/etc/chrony*" "/var/lib/chrony" )
		cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-timesync.sh <<-EOF
			echo "Setting system time via CHRONY ..."
			# Older chronyd does not have a timeout parameter.  Newer ones can be set to timeout with '-t <sec>'.
			# Must run as root since we don't have a "chrony" account.  Besides, we don't run chronyd long enough to drop privs.
			chronyd -q -u root &
			chronyd_pid=\$!
			i=0
			while kill -0 \$chronyd_pid 2>/dev/null; do
			 	if [[ \$i -ge 10 ]]; then
			 		echo "Gave up on CHRONY after 10 seconds."
			 		kill \$chronyd_pid
			 		break
			 	fi
			 	i=\$(( \$i + 1 ))
			 	sleep 1
			done
		EOF
		;;
	RDATE)
		[ "$TIMESYNC_SOURCE" ]
		StopIfError "TIMESYNC_SOURCE not set, please set it to your RDATE server in $CONFIG_DIR/local.conf"
		PROGS=( "${PROGS[@]}" rdate )
		cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-timesync.sh <<-EOF
			echo "Setting system time via RDATE ..."
			rdate -l -p -s "$TIMESYNC_SOURCE" # allow for big jumps
		EOF

		;;
	NTPDATE)
		[ "$TIMESYNC_SOURCE" ]
		StopIfError "TIMESYNC_SOURCE not set, please set it to your NTPDATE server in $CONFIG_DIR/local.conf"
		PROGS=( "${PROGS[@]}" ntpdate )
		cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-timesync.sh <<-EOF
			echo "Setting system time via NTPDATE ..."
			ntpdate -b "$TIMESYNC_SOURCE" # allow for big jumps
		EOF

		;;
	"")
		# no timesync, do nothing
		;;
	*)
		Error "TIMESYNC set to invalid value [$TIMESYNC]. Can be one of 'NTP','RDATE',''."
		;;
esac

if [[ -s $ROOTFS_DIR/etc/scripts/system-setup.d/90-timesync.sh ]]; then
	chmod $v +x $ROOTFS_DIR/etc/scripts/system-setup.d/90-timesync.sh >&2
fi

true
