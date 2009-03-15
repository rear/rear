# report about checks beeing done

if test "$NOBOOTLOADER" ; then
	LogPrint "WARNING ! For this system ($OS_VENDOR_VERSION on $ARCH) there is
	no code to install a boot loader on the recovered system.

	Please contribute this code to the $PRODUCT project. To do so
	please take a look at the scripts in $SHARE_DIR/finalize,
	for an example you can use the script for CentOS in
	$SHARE_DIR/finalize/CentOS/i386/#20_install_grub.sh

	--------------------  ATTENTION ATTENTION ATTENTION -------------------
	|                                                                     |
	|          IF YOU DO NOT INSTALL A BOOT LOADER MANUALLY,              |
	|                                                                     |
	|          THEN YOUR SYSTEM WILL N O T BE ABLE TO BOOT !              |
	|                                                                     |
	-----------------------------------------------------------------------
	"
fi	
