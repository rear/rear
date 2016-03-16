# force ldconfig here for backward compatibility reasons (e.g. no systemd present)
if [[ -f /etc/ld.so.conf ]]; then
   /bin/ldconfig -X
fi
