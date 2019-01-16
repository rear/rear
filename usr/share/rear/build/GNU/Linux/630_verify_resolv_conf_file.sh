
# Try to verify that the /etc/resolv.conf file in the ReaR recovery system
# contains content that is actually usable within the recovery system.
#
# We do not want to replicate in the recovery system
# whatever complicated DNS setup there is on the original system
# (like systemd-resolved).
# In the recovery system a plain traditional /etc/resolv.conf file
# with some actually usable content should be sufficient, cf.
# https://github.com/rear/rear/issues/2015#issuecomment-454749972

# Use what the user specified as /etc/resolv.conf in the recovery system:
if test "$USE_RESOLV_CONF" ; then
    rm -f $ROOTFS_DIR/etc/resolv.conf
    local resolv_conf_line
    for resolv_conf_line in "${USE_RESOLV_CONF[@]}" ; do
        echo "$resolv_conf_line" >>$ROOTFS_DIR/etc/resolv.conf
    done
fi

# Ensure /etc/resolv.conf in the recovery system contains actual content.
# Because of the issues
# https://github.com/rear/rear/issues/520
# https://github.com/rear/rear/issues/1200
# https://github.com/rear/rear/issues/2015
# where on Ubuntu /etc/resol.conf is linked to /run/resolvconf/resolv.conf
# and since Ubuntu 18.x /etc/resol.conf is linked to /lib/systemd/resolv.conf
# so that we need to remove the link and have the actual content in /etc/resolv.conf
# (in case of USE_RESOLV_CONF /etc/resolv.conf in the recovery system is no symbolic link):
if test -h $ROOTFS_DIR/etc/resolv.conf ; then
    rm -f $ROOTFS_DIR/etc/resolv.conf
    cp $v /etc/resolv.conf $ROOTFS_DIR/etc/resolv.conf
fi

# Check that the content in /etc/resolv.conf in the recovery system
# seems to be actually usable within the recovery system:
# On Ubuntu 18.x versions /etc/resol.conf is linked to /lib/systemd/resolv.conf
# where its actual content is only the following single line
#   nameserver 127.0.0.53
# cf. https://github.com/rear/rear/issues/2015#issuecomment-454082087
# but a loopback IP address for the DNS nameserver cannot work within
# the recovery system because there is no DNS server listening at 127.0.0.53
# because systemd-resolved is not running within the recovery system.
# According to "man resolv.conf"
#   ... the keyword (e.g., nameserver) must start the line.
#   The value follows the keyword, separated by white space.
local only_loopback_nameservers="yes"
local keyword nameserver_IP_address junk
while read keyword nameserver_IP_address junk ; do
    test "$nameserver_IP_address" || continue
    # One non-empty and non-loopback nameserver IP address is considered to be valid
    # (i.e. we do not verify here if a nameserver does actually work):
    if grep -q '^127\.' <<<"$nameserver_IP_address" ; then
        Log "Useless loopback nameserver IP address $nameserver_IP_address in $ROOTFS_DIR/etc/resolv.conf"
    else
        only_loopback_nameservers="no"
        Log "Supposedly valid nameserver IP address $nameserver_IP_address in $ROOTFS_DIR/etc/resolv.conf"
        # We may no 'break' here if we like to 'Log' all supposedly valid nameserver IP addresses:
        break
    fi
done < <( grep '^nameserver[[:space:]]' $ROOTFS_DIR/etc/resolv.conf )
# It is o.k. to have an empty /etc/resolv.conf in the recovery system
# (perhaps no DNS should be used within the recovery system)
# but when /etc/resolv.conf in the recovery system contains nameserver values
# it means DNS should be used within the recovery system and then things cannot work
# when only loopback nameservers are specified so that we error out in this case:
if is_true "$only_loopback_nameservers" ; then
    Error "Recovery system etc/resolv.conf contains no real nameserver (e.g. only loopback addresses 127.*), specify a real nameserver via USE_RESOLV_CONF"
else
    # The 'true' avoids that this script results a non-zero exit code which would cause a Debug message (in debug mode)
    #   Source function: 'source /usr/share/rear/build/GNU/Linux/630_verify_resolv_conf_file.sh' returns 1
    true
fi

