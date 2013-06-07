### Verify that a filesystem has been mounted at /mnt/local
### Failure would lead to OOM conditions (restore to the ramdisk)

if diff -u <( df -P /mnt/local ) <( df -P / ) >&8 ; then
    Error "No filesystem mounted on /mnt/local. Stopping."
fi
