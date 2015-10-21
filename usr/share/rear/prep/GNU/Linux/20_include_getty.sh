# 20_include_getty.sh
# investigate which getty this system has in use and add it to the REQUIRED_PROGS array
# older Linux distro's use usually mingetty, but newer ones stick to agetty to spawn ttys
# except debian and ubuntu who are using getty instead

pgrep -nx mingetty 1>/dev/null && REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" mingetty )
pgrep -nx agetty   1>/dev/null && REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" agetty )
pgrep -nx getty    1>/dev/null && REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" getty )

# if a REQUIRED_PROGS is missing rear will complain and stop
