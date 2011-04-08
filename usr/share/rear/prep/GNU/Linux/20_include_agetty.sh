# For serial support we need to include the agetty binary, but Debian distro's
# use getty instead of agetty.

# if the variable is not set or defined as n/N then we do nothing
[ -z "$USE_SERIAL_CONSOLE" ] && return
if [ "x${USE_SERIAL_CONSOLE}" = "xN" ] || [ "x${USE_SERIAL_CONSOLE}" = "xn" ]; then 
	return
fi

if [ -f /sbin/getty ]; then
	# Debian, Ubuntu,...
	GETTY=getty
elif [ -f /sbin/agetty ]; then
	# Fedora, RHEL, SLES,...
	GETTY=agetty
else
	# being desperate (not sure this is the best choice?)
	BugError "Could not find a suitable (a)getty for serial console. Please fix
$SHARE_DIR/prep/GNU/Linux/20_include_agetty.sh" 
fi
Log "Serial Console support requested - adding required program $GETTY"

REQUIRED_PROGS=(
"${REQUIRED_PROGS[@]}"
"${GETTY}"
)
