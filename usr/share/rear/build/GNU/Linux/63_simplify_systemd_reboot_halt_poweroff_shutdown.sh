
# In case of systemd simplify how reboot halt poweroff and shutdown works
# to make it more fail-safe, cf. https://github.com/rear/rear/issues/953

# Skip if systemd is not used:
test -d $ROOTFS_DIR/usr/lib/systemd/system || return 0

# Replace reboot halt and poweroff by simple scripts that run
# "umount -a ; systemctl --force [reboot halt poweroff]"
for command in reboot halt poweroff ; do
cat <<EOF >$ROOTFS_DIR/bin/$command
#!/bin/bash
echo umounting all filesystems
umount -vfar
echo $command in 3 seconds...
sleep 3
systemctl --force $command
EOF
done

# Because there is no "systemctl shutdown" replace shutdown
# by a more elaborated script that calls by default poweroff
# but when '-r' or '--reboot' is specified it calls reboot and
# when '-H' or '--halt' is specified it calls halt:
cat <<'EOF' >$ROOTFS_DIR/bin/shutdown
#!/bin/bash
command=poweroff
for arg in "$@" ; do
    case "$arg" in
        (-r|--reboot) command=reboot ;;
        (-H|--halt)   command=halt ;;
    esac
done
$command
EOF

