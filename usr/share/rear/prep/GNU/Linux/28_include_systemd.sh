# Fedora 15 is using systemd as init mechanism

if ps ax | grep -v grep | grep -q systemd ; then
	PROGS=( "${PROGS[@]}" systemd agetty systemctl systemd-notify systemd-ask-password
		systemd-udevd systemd-journald journalctl dbus-uuidgen dbus-daemon dbus-send
		upstart-udev-bridge )
	# cgroup stuff - not required for rear
	#PROGS=( "${PROGS[@]}" cg_annotate cgclear cgcreate cgget cgrulesengd cgset cgdelete cgclassify cgexec )
	COPY_AS_IS=( "${COPY_AS_IS[@]}" /usr/share/systemd /etc/dbus-1 /usr/lib/systemd/systemd-* /lib/systemd/systemd-* )
	Log "Including systemd (init replacement) tool-set to bootstrap Relax-and-Recover"
fi
