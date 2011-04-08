# some things are special

# XEN PV does not autoload some modules
if [ -d /proc/xen ] ; then
	modprobe xenblk
fi
