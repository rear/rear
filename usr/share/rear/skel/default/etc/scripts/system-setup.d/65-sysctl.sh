# run sysctl /etc/sysctl.conf and /etc/sysctl.d/*.conf files
for file in /etc/sysctl.d/*.conf ; do
    test -f "$file" && sysctl -e -p "$file" >/dev/null 2>&1
done
test -f /etc/sysctl.conf && sysctl -e -p /etc/sysctl.conf >/dev/null 2>&1
