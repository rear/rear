# Detect if SELinux is in use and set corresponding variables

# Check if SELinux enforce file exists
if [ -f /selinux/enforce ] ; then
    SELINUX_ENFORCE=/selinux/enforce
elif [ -f /sys/fs/selinux/enforce ] ; then
    SELINUX_ENFORCE=/sys/fs/selinux/enforce
else
    Log "SELinux is not in use (neither /selinux/enforce nor /sys/fs/selinux/enforce exists)"
    return
fi

# SELinux is in use
SELINUX_IN_USE=1

# Read current SELinux enforcing mode (0=permissive, 1=enforcing)
SELINUX_ENFORCING=$( cat $SELINUX_ENFORCE )

# Include SELinux utilities in the rescue system
PROGS+=( getenforce setenforce sestatus setfiles chcon restorecon )

# Include SELinux configuration directory
COPY_AS_IS+=( /etc/selinux )

# Alter kernel command line to enable SELinux in permissive mode in the rescue system
# Replace 'selinux=0' with 'selinux=1' if 'selinux=0' exists
KERNEL_CMDLINE=$( echo $KERNEL_CMDLINE | sed -e 's/selinux=0/selinux=1/' )
# Append 'selinux=1' if no 'selinux=1' exists
echo $KERNEL_CMDLINE | grep -q 'selinux=1' || KERNEL_CMDLINE+=" selinux=1"
# Replace 'enforcing=1' with 'enforcing=0' if 'enforcing=1' exists
KERNEL_CMDLINE=$( echo $KERNEL_CMDLINE | sed -e 's/enforcing=1/enforcing=0/' )
# Append 'enforcing=0' if no 'enforcing=' exists
echo $KERNEL_CMDLINE | grep -q 'enforcing=' || KERNEL_CMDLINE+=" enforcing=0"

# Check if SELinux should be disabled during backup
if is_true "$BACKUP_SELINUX_DISABLE" ; then
    # Save current SELinux mode to restore it after backup
    cat $SELINUX_ENFORCE > $TMP_DIR/selinux.mode
fi
