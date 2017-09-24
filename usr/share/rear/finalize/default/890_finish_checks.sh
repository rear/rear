# report about checks being done

if ls -l /sys/block/*/ | grep -q xen ; then
    # if some disks are xen related then assume this is a XEN PV VM which boots externally
    LogPrint "This looks like a XEN PV system, ignoring boot loader issues"
elif test "$NOBOOTLOADER" ; then
    LogPrint "WARNING:
For this system
$OS_VENDOR_VERSION on $ARCH (based on $OS_MASTER_VENDOR_VERSION_ARCH)
there is no code to install a boot loader on the recovered system
or the code that we have failed to install the boot loader correctly.
Please contribute appropriate code to the $PRODUCT project,
see http://relax-and-recover.org/development/
Take a look at the scripts in $SHARE_DIR/finalize,
for example see the scripts
$SHARE_DIR/finalize/Linux-i386/210_install_grub.sh
$SHARE_DIR/finalize/Linux-i386/220_install_grub2.sh

---------------------------------------------------
|  IF YOU DO NOT INSTALL A BOOT LOADER MANUALLY,  |
|  THEN YOUR SYSTEM WILL NOT BE ABLE TO BOOT.     |
---------------------------------------------------

You can use 'chroot $TARGET_FS_ROOT bash --login'
to change into the recovered system.
You should at least mount /proc in the recovered system
e.g. via 'mount -t proc none $TARGET_FS_ROOT/proc'
before you change into the recovered system
and manually install a boot loader therein.
"

fi
