# ia64 systems have a LAN console which makes it easier to grab control remotely
# therefore, we need to add ttyS0 or ttyS1 to isolinux command line to see something
# default settings
CONSOLE="console=tty0 console=ttyS0"
dmesg | grep console | grep MMIO | grep ttyS1 >/dev/null 2>&1
if [ $? -eq 0 ]; then
	# ttyS1 found
	CONSOLE="console=tty1 console=ttyS1"
fi
