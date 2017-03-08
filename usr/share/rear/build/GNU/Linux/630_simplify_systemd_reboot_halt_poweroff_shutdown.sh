
# build/GNU/Linux/630_simplify_systemd_reboot_halt_poweroff_shutdown.sh
# simplifies how reboot halt poweroff and shutdown work in case of systemd
# to make them more fail-safe, see https://github.com/rear/rear/issues/953

# Skip if systemd is not used.
# Because the scripts below need the systemctl executable and because
# via prep/GNU/Linux/280_include_systemd.sh and build/GNU/Linux/100_copy_as_is.sh
# systemctl gets only copied into the recovery system if systemd is used,
# we can test here (i.e. after build/GNU/Linux/100_copy_as_is.sh had already run)
# if /bin/systemctl exists in the recovery system:
test -x $ROOTFS_DIR/bin/systemctl || return 0

# Replace reboot halt and poweroff by simple scripts that basically run
#   "umount -a ; sync ; systemctl --force [reboot halt poweroff]"
# where umount plus sync are explicitly run first of all to be on the safe side
# regardless that "systemctl [reboot halt poweroff]" should also do it
# according to what "man systemctl" (in systemd-228) reads:
#   "all file systems are unmounted or mounted read-only,
#    immediately followed by the [reboot halt poweroff]"
# but who knows how things may work different in various systemd versions
# (one same Relax-and-Recover code must work on various different systems)
# and in "unmounted ... immediately followed by [reboot halt poweroff]"
# the "immediately" looks a bit scaring - does it perhaps not wait reasonably
# until writing to persistent storage devices has actually finished
# (we wait 3 seconds for caches inside storage devices cf. "man 2 sync").
# Furthermore to be safe against links first remove an existing file or link and
# create it anew from scratch as regular file with sufficient permission settings.
for command in reboot halt poweroff ; do
filename=$ROOTFS_DIR/bin/$command
rm -f $filename
cat <<EOF >$filename
#!/bin/bash
# script to make $command working more simple and fail-safe
# see https://github.com/rear/rear/issues/953
# and 630_simplify_systemd_reboot_halt_poweroff_shutdown.sh
export LC_ALL=C LANG=C
echo umounting all filesystems
umount -vfar
echo syncing disks... waiting 3 seconds before $command
sync
sleep 3
systemctl --force $command
EOF
chmod a+rx $filename
done

# Because there is no "systemctl shutdown" replace shutdown
# by a more elaborated script that calls by default poweroff
# (i.e. it should call the above created poweroff script)
# because "man shutdown" (in systemd-228) reads
#   "Power-off the machine (the default)"
# but when '-r' or '--reboot' is specified it calls reboot and
# when '-H' or '--halt' is specified it calls halt.
filename=$ROOTFS_DIR/bin/shutdown
rm -f $filename
# No variable evaluation when creating the shutdown script (quoted 'EOF'):
cat <<'EOF' >$filename
#!/bin/bash
# script to make shutdown working more simple and fail-safe
# see https://github.com/rear/rear/issues/953
# and 630_simplify_systemd_reboot_halt_poweroff_shutdown.sh
export LC_ALL=C LANG=C
command=poweroff
for arg in "$@" ; do
    case "$arg" in
        (-r|--reboot) command=reboot ;;
        (-H|--halt)   command=halt ;;
    esac
done
$command
EOF
chmod a+rx $filename

