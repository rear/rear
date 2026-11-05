# Inform the user when the bootloader installation was not successful
# except on XEN PV that has an external boot loader:

if ls -l /sys/block/*/ | grep -q xen ; then
    # If some disks are XEN related assume this is a XEN PV VM which boots externally
    # cf. https://github.com/rear/rear/commit/6d529feb3c580ebd4c60d134dbba86b2e7585042
    LogPrint "Ignoring boot loader issues: Assuming a XEN PV VM which boots externally (found 'xen' in /sys/block/*/)"
    return 0
fi

if test "$NOBOOTLOADER" ; then
    LogPrint "WARNING:
For this system
$OS_VENDOR_VERSION on $ARCH (based on $OS_MASTER_VENDOR_VERSION_ARCH)
there is no code to install a boot loader on the recovered system
or the code that we have failed to install the boot loader correctly.
Please contribute appropriate code to the $PRODUCT project,
see http://relax-and-recover.org/development/
Take a look at the scripts in $SHARE_DIR/finalize - for example
for PC architectures like x86 and x86_64 see the script
$SHARE_DIR/finalize/Linux-i386/660_install_grub2.sh
and for POWER architectures like ppc64le see the script
$SHARE_DIR/finalize/Linux-ppc64le/660_install_grub2.sh
---------------------------------------------------
|  IF YOU DO NOT INSTALL A BOOT LOADER MANUALLY,  |
|  THEN YOUR SYSTEM WILL NOT BE ABLE TO BOOT.     |
---------------------------------------------------
You can use 'chroot $TARGET_FS_ROOT bash --login'
to change into the recovered system and
manually install a boot loader therein.
"
fi
