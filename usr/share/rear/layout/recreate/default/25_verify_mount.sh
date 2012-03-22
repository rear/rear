### Verify that a filesystem has been mounted at /mnt/local
### Failure would lead to OOM conditions (restore to the ramdisk)

if diff <( df /mnt/local ) <( df / ) >&8 ; then
    Error "No filesystem mounted on /mnt/local. Stopping."
fi
