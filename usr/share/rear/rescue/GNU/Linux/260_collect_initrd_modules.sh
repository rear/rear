# purpose is to saved the current list of modules in the running initrd image
: > $VAR_DIR/recovery/initrd_modules
for m in $( gunzip -c /boot/{initrd,initramfs}-${KERNEL_VERSION}.img 2>/dev/null | cpio -t 2>/dev/null | grep ".ko$" )
do
	basename $m .ko >> $VAR_DIR/recovery/initrd_modules
done
