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
# Using 'grep -vE " type (this|that) "' makes it look like bloatware code
# cf. https://github.com/rear/rear/pull/1459#discussion_r135744282
# but currently I <jsmeix@suse.de> prefer "bloatware code" that works fail safe
# over simple code that sometimes fails, cf. "Dirty hacks welcome"
# at https://github.com/rear/rear/wiki/Coding-Style
# All elements of the 'pseudofs' array in libmount/src/utils.c
# cf. https://github.com/karelzak/util-linux/blob/master/libmount/src/utils.c
# are considered as unwanted "noise" in this context
# see https://github.com/rear/rear/pull/1648
local excluded_fs_types="anon_inodefs|autofs|bdev|cgroup|cgroup2|configfs|cpuset|debugfs|devfs|devpts|devtmpfs|dlmfs|efivarfs|fuse.gvfs-fuse-daemon|fusectl|hugetlbfs|mqueue|nfsd|none|nsfs|overlay|pipefs|proc|pstore|ramfs|rootfs|rpc_pipefs|securityfs|sockfs|spufs|sysfs|tmpfs"
# Mountpoints of "type autofs" are excluded via excluded_fs_types above.
# Also exclude mountpoints that are below mountpoints of "type autofs",
# see https://github.com/rear/rear/issues/2610
# Such mountpoints are below an ancestor mountpoint that is owned/created by the automounter.
# It is possible to create a sub-mountpoint below an automounted mountpoint
# but the fact that the sub-mountpoint is not local means it should be excluded
# (i.e. there is no need to recreate the non-local sub-mountpoint directory).
# Furthermore automounted NFS filesystems can cause this script to hang up if NFS server fails
# because the below 'stat' command may then wait indefinitely for the NFS server to respond.
# Assume 'mount' shows (excerpts)
# <something> on /some/mp type autofs (...)
# <some_NFS_export> on /some/mp/sub_mp type nfs (...)
# <something_else> on /other/mp type autofs (...)
# <other_NFS_export> on /other/mp/sub_mp1 type nfs (...)
# <other_NFS4_export> on /other/mp/sub_mp2 type nfs4 (...)
# then
# autofs_mountpoints="/some/mp
# /other/mp"
# (there are newlines in between) and
# autofs_and_below_mountpoints=( /some/mp /some/mp/sub_mp /other/mp /other/mp/sub_mp1 /other/mp/sub_mp2 )
# and
# exclude_autofs_and_below_mountpoints="/some/mp|/some/mp/sub_mp|/other/mp|/other/mp/sub_mp1|/other/mp/sub_mp2"
# otherwise when there is no mountpoint of "type autofs" then exclude_autofs_and_below_mountpoints is empty:
local exclude_autofs_and_below_mountpoints=''
local autofs_mountpoints="$( mount | grep " type autofs " | awk '{print $3}' )"
if test "$autofs_mountpoints" ; then
    local autofs_and_below_mountpoints=()
    local autofs_mountpoint
    for autofs_mountpoint in $autofs_mountpoints ; do
        # Using findmnt option '-T' but not '-M' which is not supported on Fedora based distributions
        # at least not on RHEL 7.9 cf. https://github.com/rear/rear/pull/2613#pullrequestreview-654678482
        autofs_and_below_mountpoints+=( $( findmnt -R -T $autofs_mountpoint -n -o TARGET --raw ) )
    done
    exclude_autofs_and_below_mountpoints="$( tr ' ' '|' <<<"${autofs_and_below_mountpoints[@]}" )"
fi
# BUILD_DIR can be used in 'grep -vE "this|$BUILD_DIR|that"' because it is never empty (see usr/sbin/rear).
# USB_DEVICE_FILESYSTEM_LABEL must not be empty otherwise 'grep -vE "this|that|"' would output nothing at all:
contains_visible_char "$USB_DEVICE_FILESYSTEM_LABEL" || USB_DEVICE_FILESYSTEM_LABEL="REAR-000"
local excluded_other_stuff="/sys/|$BUILD_DIR|$USB_DEVICE_FILESYSTEM_LABEL"
# The trailing space in 'type ($excluded_fs_types) |' is intentional:
local mountpoints
# Avoid that 'grep -v' outputs nothing when exclude_autofs_and_below_mountpoints is empty
# i.e. when there is no mountpoint of "type autofs":
if test "$exclude_autofs_and_below_mountpoints" ; then
    mountpoints="$( mount | grep -vE " type ($excluded_fs_types) | on ($exclude_autofs_and_below_mountpoints) |$excluded_other_stuff" | awk '{print $3}' )"
else
    mountpoints="$( mount | grep -vE " type ($excluded_fs_types) |$excluded_other_stuff" | awk '{print $3}' )"
fi
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
        grep -q "^$directory " "$directories_permissions_owner_group_file" && continue
        # Skip when it is neither a normal directory nor a symbolic link that points to a normal directory
        # which means: Skip when it does not exist on the currently running system:
        if ! test -d "$directory" ; then
            Log "FHS directory $directory does not exist"
            continue
        fi
        # Symbolic links are output different than normal directories:
        if test -L "$directory" ; then
            # On SLES11 symbolic links are output e.g. like
            #   # stat -c '%N' "/var/mail"
            #   `/var/mail' -> `spool/mail'
            # while since SLES12 symbolic links are output e.g. like
            #   # stat -c '%N' "/var/mail"
            #   '/var/mail' -> 'spool/mail'
            # so we remove the characters ' and ` (octal \047 and \140) to get plain
            #   /var/mail -> spool/mail
            # FIXME: This code fails when the symlink or its target contains special characters
            # cf. https://github.com/rear/rear/issues/1372
            stat -c '%N' "$directory" | tr -d '\047\140' >>"$directories_permissions_owner_group_file"
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

