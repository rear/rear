# 200_include_getty.sh
# investigate which getty this system has in use and add it to the REQUIRED_PROGS array
# older Linux distro's use usually mingetty, but newer ones stick to agetty to spawn ttys
# except debian and ubuntu who are using getty instead

pgrep -nx mingetty 1>/dev/null && REQUIRED_PROGS+=( mingetty )
pgrep -nx agetty   1>/dev/null && REQUIRED_PROGS+=( agetty )
pgrep -nx getty    1>/dev/null && REQUIRED_PROGS+=( getty )

# if a REQUIRED_PROGS is missing rear will complain and stop

# if above commands do not find any getty in the process tables (which is posssible thanks
# to systemd stuff) then we have a fall back as these getty's are also defined in the
# PROGS array in conf/GNU/Linux.conf
# Script build/GNU/Linux/450_symlink_mingetty.sh will link a getty to mingetty to foresee
# backwards compatibility
