### Verify that a filesystem has been mounted at $TARGET_FS_ROOT (by default /mnt/local)
### Failure would lead to OOM conditions (restore to the ramdisk)

if diff -u <( df -P $TARGET_FS_ROOT ) <( df -P / ) >/dev/null ; then
    Error "No filesystem mounted on '$TARGET_FS_ROOT'. Stopping."
fi
