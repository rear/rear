#
# usr/share/rear/prep/default/400_save_directories.sh
#
# Purpose of this script is to save permissions, owner, group
# or symbolic link name and target of basic directories in a file.
# That file will be read during recovery time to recreate those directories.
# The script restore/default/900_create_missing_directories.sh will recreate
# those directories if they were not already recreated (e.g. via backup restore)
# and all other code or scripts that also does this could/should be deleted.

local directories_permissions_owner_group_file="$VAR_DIR/recovery/directories_permissions_owner_group"
: >"$directories_permissions_owner_group_file"

# First save directories that are used as mountpoints:
# FIXME: To exclude unwanted "noise" from mountpoints a simple 'grep -vE "this|that"'
# is not fail safe because it excludes any lines that contain 'this' or 'that'.
# Using 'grep -vE "type (this|that) "' makes it look like bloatware code
# cf. https://github.com/rear/rear/pull/1459#discussion_r135744282
# but currently I <jsmeix@suse.de> prefer "bloatware code" that works fail safe
# over simple code that sometimes fails, cf. "Dirty hacks welcome"
# at https://github.com/rear/rear/wiki/Coding-Style
# All elements of the 'pseudofs' array in libmount/src/utils.c
# cf. https://github.com/karelzak/util-linux/blob/master/libmount/src/utils.c
# are considered as unwanted "noise" in this context
# see https://github.com/rear/rear/pull/1648
local excluded_fs_types="anon_inodefs|autofs|bdev|cgroup|cgroup2|configfs|cpuset|debugfs|devfs|devpts|devtmpfs|dlmfs|efivarfs|fuse.gvfs-fuse-daemon|fusectl|hugetlbfs|mqueue|nfsd|none|nsfs|overlay|pipefs|proc|pstore|ramfs|rootfs|rpc_pipefs|securityfs|sockfs|spufs|sysfs|tmpfs"
# BUILD_DIR can be used in 'grep -vE "this|$BUILD_DIR|that"' because it is never empty (see usr/sbin/rear)
# because with any empty part 'grep  -vE "this||that"' would output nothing at all:
local excluded_other_stuff="/sys/|$BUILD_DIR|$USB_DEVICE_FILESYSTEM_LABEL"
# The trailing space in 'type ($excluded_fs_types) |' is intentional:
local mountpoints="$( mount | grep -vE "type ($excluded_fs_types) |$excluded_other_stuff" | awk '{print $3}' )"
local directory
for directory in $mountpoints ; do
    # Skip the root directory '/':
    test "/" = "$directory" && continue
    # Output directory name, access rights in octal, user name of owner, group name of owner:
    stat -c '%n %a %U %G' "$directory" >>"$directories_permissions_owner_group_file"
    # Output is lines that look like (e.g. on a SLES12 system):
    # /sys 555 root root
    # /proc 555 root root
    # /dev 755 root root
    # /dev/shm 1777 root root
    # /dev/pts 755 root root
    # /run 755 root root
    # /dev/mqueue 1777 root root
    # /dev/hugepages 755 root root
    # /run/user/0 700 root root
done

# Then save FHS directories:
# The list of FHS directories was derived from https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard
FHSdirectories="/bin /boot /dev /etc /etc/opt /etc/sgml /etc/X11 /etc/xml /home /lib* /media /mnt /opt /proc /root /run /sbin /srv /sys /tmp /usr /usr/bin /usr/include /usr/lib* /usr/local /usr/sbin /usr/share /usr/src /usr/X11R6 /var /var/cache /var/lib /var/lock /var/log /var/mail /var/opt /var/run /var/spool /var/spool/mail /var/tmp"
local directoryglob
# FHSdirectories contains directories with bash globbing like /lib* and /usr/lib* that need to be expanded:
for directoryglob in $FHSdirectories ; do
    for directory in $( echo $directoryglob ) ; do
        # Skip when it is already listed in the directories_permissions_owner_group file:
        grep "^$directory" "$directories_permissions_owner_group_file" 1>&2 && continue
        # Skip when it is neither a normal directory nor a symbolic links that points to a normal directory
        # which means: Skip when it does not exist on the currently running system:
        if ! test -d "$directory" ; then
            Log "FHS directory $directory does not exist"
            continue
        fi
        # Symbolic links are output different than normal directories:
        if test -L "$directory" ; then
            stat -c '%N' "$directory" | tr -d '\047' >>"$directories_permissions_owner_group_file"
            # Symbolic links are output like (e.g. on a SLES12 system)
            # note the difference between absolute and relative symbolic link target:
            # /var/lock -> /run/lock
            # /var/mail -> spool/mail
            # /var/run -> /run
        else
            stat -c '%n %a %U %G' "$directory" >>"$directories_permissions_owner_group_file"
            # Normal directories are output as the mountpoints above like (e.g. on a SLES12 system):
            # /bin 755 root root
            # /boot 755 root root
            # /dev 755 root root
            # /etc 755 root root
            # /etc/opt 755 root root
            # /etc/X11 755 root root
            # /home 755 root root
            # /lib 755 root root
            # /lib64 755 root root
            # /mnt 755 root root
            # /opt 755 root root
            # /proc 555 root root
            # /root 700 root root
            # /run 755 root root
            # /sbin 755 root root
            # /srv 755 root root
            # /sys 555 root root
            # /tmp 1777 root root
            # /usr 755 root root
            # /usr/bin 755 root root
            # /usr/include 755 root root
            # /usr/lib 755 root root
            # /usr/lib64 755 root root
            # /usr/local 755 root root
            # /usr/sbin 755 root root
            # /usr/share 755 root root
            # /usr/src 755 root root
            # /usr/X11R6 755 root root
            # /var 755 root root
            # /var/cache 755 root root
            # /var/lib 755 root root
            # /var/log 755 root root
            # /var/opt 755 root root
            # /var/spool 755 root root
            # /var/spool/mail 1777 root root
            # /var/tmp 1777 root root
        fi
    done
done

