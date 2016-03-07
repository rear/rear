# read /etc/sysctl.conf and /etc/sysctl.d/*.conf files and parse these through sysctl
cat /etc/sysctl.d/*.conf /etc/sysctl.conf | sysctl -e -p - >&1
