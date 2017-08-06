# Fedora 15 is using systemd as init mechanism

if ps ax | grep -v grep | grep -q systemd ; then
    PROGS=( "${PROGS[@]}" systemd agetty systemctl systemd-notify systemd-ask-password
        systemd-udevd systemd-journald journalctl dbus-uuidgen dbus-daemon dbus-send
        upstart-udev-bridge )
    # cgroup stuff - not required for ReaR
    #PROGS=( "${PROGS[@]}" cg_annotate cgclear cgcreate cgget cgrulesengd cgset cgdelete cgclassify cgexec )

    # 1- Depending to the distros, systemd directory/scripts can be located in /usr/lib or /lib
    # 2- Need to add systemd/network subdir in order to preserve rules about network device naming
    #    (predictable naming or persitant naming / like udev).
    #    more info here: https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/
    COPY_AS_IS=( "${COPY_AS_IS[@]}" /usr/share/systemd /etc/dbus-1 /usr/lib/systemd/systemd-* /lib/systemd/systemd-* /usr/lib/systemd/network /lib/systemd/network /usr/lib/systemd/system-generators/systemd-getty-generator  /lib/systemd/system-generators/systemd-getty-generator )
    CLONE_GROUPS=( "${CLONE_GROUPS[@]}" input )
    Log "Including systemd (init replacement) tool-set to bootstrap Relax-and-Recover"
fi
