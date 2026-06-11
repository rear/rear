# verify that all required components for udev are present
#

# skip this script if udev is not part of the rescue system
test -d $ROOTFS_DIR/etc/udev/rules.d || return 0

# check systemd version
systemd_version="$(systemd-notify --version 2>/dev/null | grep systemd | awk '{print $2}')"
if [[ -n "$systemd_version" ]] ; then
   if ! version_newer "$systemd_version" 190 ; then
       Error "systemd version is '$systemd_version', systemd versions below 190 are not supported"
   fi
   ps ax | grep -v grep | grep -q systemd-udevd && { # check if daemon is actually running
       Log "systemd-udevd will be used - no need for udev rules rewrites"
       return 0
   }
fi

Log "Checking udev"
# check that all external programs used by udev are available
while read file location ; do
	# check for file in ROOTFS_DIR (if full path) or in lib/udev or in bin (if name without path)
	if [[ -x $ROOTFS_DIR/$file || -x $ROOTFS_DIR/lib/udev/$file || -x $ROOTFS_DIR/bin/$file ]]; then
		# everything is fine
		Log "matched external call to $file in $location"
	else
		Debug "WARNING: unmatched external call to '$file' in $location"
	fi
done < <(

	# get list of external files called in PROGRAM= or RUN= statements. The result is filtered
	# for files (no $env{...} or socket: stuff) and looks like this:

        # /bin/sed etc/udev/rules.d/56-sane-backends-autoconfig.rules:289
        # ata_id etc/udev/rules.d/60-persistent-storage.rules:39
        # /sbin/kpartx etc/udev/rules.d/70-kpartx.rules:38
        # /sbin/kpartx etc/udev/rules.d/70-kpartx.rules:40
        # /sbin/kpartx etc/udev/rules.d/70-kpartx.rules:42
        # write_cd_rules etc/udev/rules.d/75-cd-aliases-generator.rules:4
        # write_cd_rules etc/udev/rules.d/75-cd-aliases-generator.rules:6
        # ipw3945d.sh etc/udev/rules.d/77-network.rules:3
        # /sbin/ifup etc/udev/rules.d/77-network.rules:12
        # /sbin/ifdown etc/udev/rules.d/77-network.rules:13
        # /sbin/modprobe etc/udev/rules.d/80-drivers.rules:8
        # /sbin/modprobe etc/udev/rules.d/80-drivers.rules:9
        # /sbin/modprobe etc/udev/rules.d/80-drivers.rules:10
        # /sbin/modprobe etc/udev/rules.d/80-drivers.rules:11
        # /sbin/modprobe etc/udev/rules.d/80-drivers.rules:12
        # /sbin/modprobe etc/udev/rules.d/80-drivers.rules:13
        # /sbin/modprobe etc/udev/rules.d/80-drivers.rules:14
        # /usr/sbin/pcscd etc/udev/rules.d/99-pcsc_lite.rules:4
        # /usr/bin/killall etc/udev/rules.d/kino.rules:11

	# the files without a path name are supposed to be in /lib/udev

	cd  $ROOTFS_DIR
	grep -nE '(PROGRAM|RUN)' etc/udev/rules.d/* lib/udev/rules.d/* usr/lib/udev/rules.d/* | \
		sed -ne 's#\(^.*\):[0-9]\+:.*\(PROGRAM\|RUN\)[+!]\?="\([^"%\$ ]\+\).*#\3 \1#p' | \
		grep -v ^socket: | \
		sort -u
	)

# insert our module auto-loading rule
# the big and stupid problem is that some older udev versions, which we still want to support, use SYSFS{} instead of
# ATTRS{} so we have to find out how to write the rule:

# get some sysfs path with modalias in it (the printf prints it without the /sys ...)
sysfs_modalias_paths=( $(find /sys -type f -name modalias -printf "/%P\n" | sed -e 's#/modalias$##') )
# the result looks like this:
# /devices/pci0000:00/0000:00:00.0
# /devices/platform/i8042/serio1
# /devices/platform/i8042/serio0

# query the first sysfs path and choose ATTRS or SYSFS according to what *this* udev gives us
# I check for ATTR and not ATTRS because it might be either one of the two, depends on the
# sysfs path I query here and I don't predict that
if [[ "$sysfs_modalias_paths" ]] && my_udevinfo -a -p $sysfs_modalias_paths | grep '{modalias}' | grep -q ATTR ; then
	#echo 'ACTION=="add", ATTRS{modalias}=="?*", RUN+="/bin/modprobe -v $attr{modalias}"'
	# fix for https://bugzilla.novell.com/show_bug.cgi?id=581292 as suggested by Kay Sievers
	echo 'ENV{MODALIAS}=="?*", RUN+="/bin/modprobe -bv $env{MODALIAS}"'
else
	echo 'ACTION=="add", SYSFS{modalias}=="?*", RUN+="/bin/modprobe -v $sysfs{modalias}"'
fi >>$ROOTFS_DIR/etc/udev/rules.d/00-rear.rules

# udev requires certain standard groups, add them to the rescue system
# the groups and users are in rescue/default/900_clone_users_and_groups.sh

