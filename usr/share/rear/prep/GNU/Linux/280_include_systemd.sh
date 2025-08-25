# Many Linux distro's are using systemd as init mechanism

# added systemd-tmpfiles and /{usr|var}/lib/tmpfiles.d
# for Fedora (and in the future also RHEL)
# for issue #1575 (rpcbind fails to start within rescue system)
if ps ax | grep -v grep | grep -q systemd ; then
    PROGS+=( systemd agetty systemctl systemd-notify systemd-ask-password
             systemd-udevd systemd-journald journalctl
             dbus-uuidgen dbus-daemon dbus-send dbus-broker dbus-broker-launch
             upstart-udev-bridge systemd-tmpfiles )
    # cgroup stuff - not required for ReaR
    #PROGS+=( cg_annotate cgclear cgcreate cgget cgrulesengd cgset cgdelete cgclassify cgexec )

    # 1- Depending to the distros, systemd directory/scripts can be located in /usr/lib or /lib
    # 2- Need to add systemd/network subdir in order to preserve rules about network device naming
    #    (predictable naming or persitant naming / like udev).
    #    more info here: https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/
    COPY_AS_IS+=( /usr/share/systemd /etc/dbus-1 /usr/share/dbus-1
                  /usr/lib/systemd/systemd-* /lib/systemd/systemd-*
                  /usr/lib/systemd/network /lib/systemd/network
                  /usr/lib/systemd/system-generators/systemd-getty-generator
                  /lib/systemd/system-generators/systemd-getty-generator
                  /var/lib/tmpfiles.d /usr/lib/tmpfiles.d )
    CLONE_GROUPS+=( input )
    Log "Including systemd (init replacement) tool-set to bootstrap Relax-and-Recover"
fi
