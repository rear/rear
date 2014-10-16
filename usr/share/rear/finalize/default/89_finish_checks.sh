# report about checks beeing done

if ls -l /sys/block/*/ | grep -q xen ; then
	# if some disks are xen related then assume this is a XEN PV VM which boots externally
	LogPrint "This looks like a XEN PV system, ignoring boot loader issues"
elif test "$NOBOOTLOADER" ; then
	LogPrint "
WARNING ! For this system
$OS_VENDOR_VERSION on $ARCH (based on $OS_MASTER_VENDOR_VERSION_ARCH)
there is no code to install a boot loader on the recovered system or the code
that we have failed to install the boot loader correctly.

Please contribute this code to the $PRODUCT project. To do so
please take a look at the scripts in $SHARE_DIR/finalize,
for an example you can use the script for Fedora (and RHEL/CentOS/SL) in
$SHARE_DIR/finalize/Linux-i386/21_install_grub.sh or
$SHARE_DIR/finalize/Linux-i386/22_install_grub2.sh

--------------------  ATTENTION ATTENTION ATTENTION -------------------
|                                                                     |
|          IF YOU DO NOT INSTALL A BOOT LOADER MANUALLY,              |
|                                                                     |
|          THEN YOUR SYSTEM WILL N O T BE ABLE TO BOOT !              |
|                                                                     |
-----------------------------------------------------------------------

You can use 'chroot /mnt/local bash --login' to access the recovered system.
Please remember to mount /proc before trying to install a boot loader.
"

fi
