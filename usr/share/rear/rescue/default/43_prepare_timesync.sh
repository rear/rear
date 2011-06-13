# prepare environment for timesync

case "$TIMESYNC" in
	NTP)
		PROGS=( "${PROGS[@]}" ntpd )
		COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/ntp.conf )
		echo "NT:2345:respawn:/bin/ntpd -n -g -p /var/run/ntpd.pid" >>$ROOTFS_DIR/etc/inittab
		cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-timesync.sh <<-EOF
			echo "Setting system time via NTP ..."
			ntpd -q -g # allow for big jumps
		EOF
		;;
	RDATE)
		[ "$TIMESYNC_SOURCE" ]
		StopIfError "TIMESYNC_SOURCE not set, please set it to your RDATE server in $CONFIG_DIR/local.conf"
		PROGS=( "${PROGS[@]}" rdate )
		cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-timesync.sh <<-EOF
			echo "Setting system time via RDATE ..."
			rdate -s "$TIMESYNC_SOURCE" # allow for big jumps
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
