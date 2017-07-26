LogPrint "Preparing to bind mountpoints for SELinux..."
local tryCount=0
local bindCount=0
if ! is_true "$BACKUP_SELINUX_DISABLE" ; then
	LogPrint "Binding mountpoint /proc for SELinux..."
	let tryCount++ ; mount --bind /proc $TARGET_FS_ROOT/proc && let bindCount++
	LogPrint "Binding mountpoint /sys for SELinux..."
	let tryCount++ ; mount --bind /sys $TARGET_FS_ROOT/sys && let bindCount++
	LogPrint "Binding mountpoint /dev for SELinux..."
	let tryCount++ ; mount --bind /dev $TARGET_FS_ROOT/dev && let bindCount++
	LogPrint "Binding mountpoint /sys/fs/selinux for SELinux..."
	let tryCount++ ; mount --bind /sys/fs/selinux $TARGET_FS_ROOT/sys/fs/selinux && let bindCount++
fi
LogPrint "Finished binding $bindCount of $tryCount mountpoints successfully for SELinux..."
