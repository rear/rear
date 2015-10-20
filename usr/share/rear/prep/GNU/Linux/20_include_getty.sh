# 20_include_getty.sh
# investigate which getty this system has in use and add it to the REQUIRED_PROGS array
# older Linux distro's use usually mingetty, but newer ones stick to agetty to spawn ttys
# except debian and ubuntu who are using getty instead

ps ax | grep mingetty | grep -v grep && REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" mingetty )
ps ax | grep agetty   | grep -v grep && REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" agetty )
ps ax | grep "/getty" | grep -v grep && REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" getty )  # mind the / to avoid confusion with agetty

# if a REQUIRED_PROGS is missing rear will complain and stop
