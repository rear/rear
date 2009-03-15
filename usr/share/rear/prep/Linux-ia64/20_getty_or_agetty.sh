# On IA64 platforms we need the getty (Debian) or agetty (RH) program
# to be able to connect with the server via the LAN console.
# Furthermore, /etc/inittab need the approriate entries

if [ -f /sbin/getty ]; then
	GETTY=getty
elif [ -f /sbin/agetty ]; then
	GETTY=agetty
fi

REQUIRED_PROGS=(
"${REQUIRED_PROGS[@]}"
"${GETTY}"
)
