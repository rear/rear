# Newer Linux distros (SLES10++, RHEL5++, Debian 5++) support udev reasonably well to
# rely on udev and our magical module loading rule to setup all drivers for the current hardware

# For older Linux distros we fall back to manually load the modules that where loaded at the time
# of rear mkrescue

# load specified modules first
if test -s /etc/modules ; then
    while read module options ; do
        case "$module" in
            (\#*|"") ;;
            (*) modprobe -v $module $options;;
        esac
    done </etc/modules
fi

# load udev or load modules manually
# again, check if current systemd is present
systemd_version=$( systemd-notify --version 2>/dev/null | grep systemd | awk '{ print $2; }' )
# if $systemd_version is empty we put it 0 (no systemd present)
test "$systemd_version" || systemd_version=0

if [[ $systemd_version -gt 190 ]] || [[ -s /etc/udev/rules.d/00-rear.rules ]] ; then
    # systemd-udevd case: systemd-udevd is started by systemd
    # Wait up to 10 seconds for systemd-udevd:
    for countdown in 4 3 2 1 0 ; do
        # The first sleep waits one second in any case so that systemd-udevd should be usually there
        # when 'pidof' test for it so that usually there is no "Waiting for systemd-udevd" message:
        sleep 1
        pidof systemd-udevd &>/dev/null && break
        echo "Waiting for systemd-udevd ($countdown) ... "
        # The second sleep results a total wait of two seconds for each for loop run:
        sleep 1
    done
    if pidof -s systemd-udevd &>/dev/null ; then
        # check if daemon is actually running
        my_udevtrigger
        echo -n "Waiting for udev ... "
        sleep 1
        my_udevsettle
        echo "done."
    else
        # found our "special" module-auto-load rule
        # clean away old device nodes from source system
        # except Slackware since it uses eudev and relies on the kernel to create sda
        if ! grep Slackware /etc/os-release ; then
            rm -Rf /dev/{sd*,hd*,sr*,cc*,disk}
        else
            # Slackware eudev already has a rule to load modules
            rm -f /etc/udev/rules.d/00-rear.rules
        fi
        mkdir -p /dev/disk/by-{id,name,path,label}
        # everybody does that even though it seems to be empty by default..
        test -w /sys/kernel/uevent_helper && echo >/sys/kernel/uevent_helper
        # start udev daemon
        udevd --daemon
        sleep 1
        my_udevtrigger
        echo -n "Waiting for udev ... "
        sleep 3
        my_udevsettle
        echo "done."
    fi
else
    # no udev, use manual method to deal with modules

    # load block device modules, probably not in the right order
    # we load ata drivers after ide drivers to support older systems running in compatibility mode
    # most probably these lines are the cause for most problems with wrong disk order and missing block devices
    # FIXME: Please submit any better ideas !!
    # Especially how to analyse a running system and load the same drivers and bind them to the same devices in
    # the correct order
    echo "Loading storage modules..."
    for module in $( find /lib/modules/$(uname -r)/kernel/drivers/{scsi,block,ide,message,ata} -type f 2>/dev/null ) ; do
        # module extension could be .ko or .ko.xz
        filename="$( basename $module )"
        # strip everything after the first .
        modulename="${filename%%.*}"
        case "$modulename" in
            (nbd) echo "Module nbd excluded from being autoloaded.";;
            (*) modprobe -q "$modulename";;
        esac
    done
fi

# device mapper gets a special treatment here because there is no dependency to load it
modprobe -q dm-mod
