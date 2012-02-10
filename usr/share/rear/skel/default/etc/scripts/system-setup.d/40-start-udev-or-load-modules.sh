# Newer Linux distros (SLES10++, RHEL5++, Debian 5++) support udev reasonably well to
# rely on udev and our magical module loading rule to setup all drivers for the current hardware

# For older Linux distros we fall back to manually load the modules that where loaded at the time
# of rear mkrescue

# load udev or load modules manually
if test -s /etc/udev/rules.d/00-rear.rules -a -w /sys/kernel/uevent_helper ; then
	# found our "special" module-auto-load rule

	# clean away old device nodes from source system
	rm -Rf /dev/{sd*,hd*,sr*,cc*,disk}
	mkdir -p /dev/disk/by-{id,name,path,label}

	# everybody does that even though it seems to be empty by default..
	echo >/sys/kernel/uevent_helper

	# start udev daemon
	udevd --daemon
	my_udevtrigger
	echo -n "Waiting for udev ... "
	sleep 1
	my_udevsettle
	echo "done."
else
	# no udev, use manual method to deal with modules

	# load specified modules
	if test -s /etc/modules ; then
		while read module options ; do
			case "$module" in
				(\#*|"") ;;
				(*) modprobe -v $module $options;;
			esac
		done </etc/modules
	fi

	# load block device modules, probably not in the right order
	# we load ata drivers after ide drivers to support older systems running in compatibility mode
	# most probably these lines are the cause for most problems with wrong disk order and missing block devices
	#
	# Please submit any better ideas !!
	#
	# Especially how to analyse a running system and load the same drivers and bind them to the same devices in
	# the correct order
	echo "Loading storage modules..."
	for module in $(find /lib/modules/$(uname -r)/kernel/drivers/{scsi,block,ide,message,ata} -type f 2>/dev/null) ; do
		case "$(basename $module .ko)" in
			(nbd) echo "Module nbd excluded from being autoloaded.";;
			(*) modprobe -q $(basename $module .ko);;
		esac
	done
fi

# device mapper gets a special treatment here because there is no dependency to load it
modprobe -q dm-mod
