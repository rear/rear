# 700_persistent_interface.sh
# We will check if the current LAN interface are persistent or not via function is_persistent_ethernet_name (which
# is part of the lib/network-functions.sh library). The function returns true (0) when we are dealing with a
# persistent LAN interface.
# Furthermore, if the $KERNEL_CMDLINE variable contains "net.ifnames=0" and we are currently using persistent
# names then we should remove this value from KERNEL_CMDLINE as otherwise in recover mode we will be using ethernet
# aliases like eth0 or eth1. It should remain the same if we want our network/routing scripts to be functional.

# $ ip r | awk '$2 == "dev" && $8 == "src" { print $3 }' | sort -u | head -1
# enp0s3

# if we are NOT using persistent naming just silently return
is_persistent_ethernet_name $(ip r | awk '$2 == "dev" && $8 == "src" { print $3 }' | sort -u | head -1) || return

# When the KERNEL_CMDLINE does NOT contain net.ifnames=0 silently return
echo $KERNEL_CMDLINE | grep -q 'net.ifnames=0' || return

# Remove net.ifnames=0 from KERNEL_CMDLINE
KERNEL_CMDLINE=$( echo $KERNEL_CMDLINE | sed -e 's/net.ifnames=0//' )
