# Newer Linux distros (SLES10++, RHEL5++, Debian 5++) support udev reasonably well to
# rely on udev and our magical module loading rule to setup all drivers for the current hardware

# For older Linux distros we fall back to manually load the modules that where loaded at the time
# of rear mkrescue

# load udev or load modules manually
# again, check if current systemd is present
systemd_version=$(systemd-notify --version 2>/dev/null | grep systemd | awk '{ print $2; }')
# if $systemd_version is empty we put it 0 (no systemd present)
[[ -z "$systemd_version" ]] && systemd_version=0

if [[ $systemd_version -gt 190 ]] || [[ -s /etc/udev/rules.d/00-rear.rules ]] ; then

    # systemd-udevd case: systemd-udevd is started by systemd
    ps ax | grep -v grep | grep -q systemd-udevd && { # check if daemon is actually running
        my_udevtrigger
        echo -n "Waiting for udev ... "
        sleep 1
        my_udevsettle
        echo "done."
        return
    }

    # found our "special" module-auto-load rule

    # clean away old device nodes from source system
    rm -Rf /dev/{sd*,hd*,sr*,cc*,disk}
    mkdir -p /dev/disk/by-{id,name,path,label}

    # everybody does that even though it seems to be empty by default..
    if [[ -w /sys/kernel/uevent_helper ]]; then
        echo >/sys/kernel/uevent_helper
    fi

    # start udev daemon
    udevd --daemon
    sleep 1
    my_udevtrigger
    echo -n "Waiting for udev ... "
    sleep 3
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
        filename="$(basename $module)"   # module extention could be .ko or .ko.xz
        modulename="${filename%%.*}"     # strip everything after the first .
        case "$modulename" in
            (nbd) echo "Module nbd excluded from being autoloaded.";;
            (*) modprobe -q "$modulename";;
        esac
    done
fi

# device mapper gets a special treatment here because there is no dependency to load it
modprobe -q dm-mod

# When udevd or systemd is in place then out /etc/modules content is skipped, however, we
# might need it for e.g. loading fuse which was added to the MODULES_LOAD array
# There might be other kernel modules added by the user on demand, therefore, we always
# load the modules found in /etc/modules
if test -s /etc/modules ; then
    while read module options ; do
    case "$module" in
        (\#*|"") ;;
        (*) modprobe -v $module $options;;
    esac
    done </etc/modules
fi


