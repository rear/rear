# if the variable is not set or defined as n/N then we do nothing
[ -z "$USE_SERIAL_CONSOLE" ] && return
if [ "x${USE_SERIAL_CONSOLE}" = "xN" ] || [ "x${USE_SERIAL_CONSOLE}" = "xn" ]; then 
	return
fi

echo "
s0:2345:respawn:/sbin/$GETTY 115200 ttyS0 vt100
s1:2345:respawn:/sbin/$GETTY 115200 ttyS1 vt100

" >>$ROOTFS_DIR/etc/inittab
Log "Serial Console support requested - adding required entries for $GETTY in inittab"
