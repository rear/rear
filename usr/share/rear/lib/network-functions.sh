#
# ReaR networking functions.
#
# MASKS, prefix2netmask, num2ip, and get_device_by_hwaddr
# are originally from an old fedora-14 dhclient-script
# that was there used for DHCP setup and is still used in ReaR
# for  DHCP setup in skel/default/etc/scripts/dhcp-setup-functions.sh
# cf. https://github.com/rear/rear/issues/1517

NETMASKS_BINARY=( 0
                  10000000000000000000000000000000
                  11000000000000000000000000000000
                  11100000000000000000000000000000
                  11110000000000000000000000000000
                  11111000000000000000000000000000
                  11111100000000000000000000000000
                  11111110000000000000000000000000
                  11111111000000000000000000000000
                  11111111100000000000000000000000
                  11111111110000000000000000000000
                  11111111111000000000000000000000
                  11111111111100000000000000000000
                  11111111111110000000000000000000
                  11111111111111000000000000000000
                  11111111111111100000000000000000
                  11111111111111110000000000000000
                  11111111111111111000000000000000
                  11111111111111111100000000000000
                  11111111111111111110000000000000
                  11111111111111111111000000000000
                  11111111111111111111100000000000
                  11111111111111111111110000000000
                  11111111111111111111111000000000
                  11111111111111111111111100000000
                  11111111111111111111111110000000
                  11111111111111111111111111000000
                  11111111111111111111111111100000
                  11111111111111111111111111110000
                  11111111111111111111111111111000
                  11111111111111111111111111111100
                  11111111111111111111111111111110
                  11111111111111111111111111111111
                  -1 )

NETMASKS_DECIMAL=( $( for mask in "${NETMASKS_BINARY[@]}" ; do echo "ibase=2 ; $mask" | bc -l ; done ) )
# NETMASKS_DECIMAL is the same as
# MASKS=( 0
#         2147483648       3221225472       3758096384       4026531840
#         4160749568       4227858432       4261412864       4278190080
#         4286578688       4290772992       4292870144       4293918720
#         4294443008       4294705152       4294836224       4294901760
#         4294934528       4294950912       4294959104       4294963200
#         4294965248       4294966272       4294966784       4294967040
#         4294967168       4294967232       4294967264       4294967280
#         4294967288       4294967292       4294967294       4294967295
#         -1 )
# and those numbers match the following IP addresses according to the output of
#   for mask in "${NETMASKS_DECIMAL[@]}" ; do num2ip $mask ; done
#         0.0.0.0
#         128.0.0.0        192.0.0.0        224.0.0.0        240.0.0.0
#         248.0.0.0        252.0.0.0        254.0.0.0        255.0.0.0
#         255.128.0.0      255.192.0.0      255.224.0.0      255.240.0.0
#         255.248.0.0      255.252.0.0      255.254.0.0      255.255.0.0
#         255.255.128.0    255.255.192.0    255.255.224.0    255.255.240.0
#         255.255.248.0    255.255.252.0    255.255.254.0    255.255.255.0
#         255.255.255.128  255.255.255.192  255.255.255.224  255.255.255.240
#         255.255.255.248  255.255.255.252  255.255.255.254  255.255.255.255
#         255.255.255.255

# Output the IP address that match a decimal number:
function num2ip () {
    local num=$1
    let octet1="(num >> 24) & 0xff"
    let octet2="(num >> 16) & 0xff"
    let octet3="(num >> 8) & 0xff"
    let octet4="num & 0xff"
    echo $octet1.$octet2.$octet3.$octet4
}

# Output the netmask in IP address format nnn.nnn.nnn.nnn for a prefix, for example:
#   prefix2netmask 1   results   128.0.0.0
#   prefix2netmask 2   results   192.0.0.0
#   prefix2netmask 8   results   255.0.0.0
#   prefix2netmask 16  results   255.255.0.0
#   prefix2netmask 24  results   255.255.255.0
function prefix2netmask () {
    local prefix=$1
    test $prefix -gt 32 && BugError "function prefix2netmask() called with prefix '$prefix' > 32"
    num2ip ${NETMASKS_DECIMAL[$prefix]}
}

# Output all network interfaces (here falsely called 'device' and even in singular)
# each one on a separated line (i.e. each one separated by '\n')
# that belong to a hardware address (MAC address), for example on commandline:
#   # hwaddr="64:00:6A:64:C0:06"
#   # ip -o link | grep -v 'link/ieee802.11' | grep -i "$hwaddr"
#   2: eth0:  ...  link/ether 64:00:6a:64:c0:06  ...
#   3: br0:   ...  link/ether 64:00:6a:64:c0:06  ...
#   # ip -o link | grep -v 'link/ieee802.11' | grep -i "$hwaddr" | awk -F ": " '{print $2}'
#   eth0
#   br0
function get_device_by_hwaddr () {
    local hwaddr="$1"
    ip -o link | grep -v 'link/ieee802.11' | grep -i "$hwaddr" | awk -F ": " '{print $2}'
}

# Retun 0 if args is a valid IPV4 ip_address
function is_ip () {
    local test_ip=$1
    [ -z "$test_ip" ] && BugError "function is_ip() called without argument."

    # ip_pattern variable is used to store a regex which validate an IPV4 address: "[0 to 255].[0 to 255].[0 to 255].[0 to 255]".
    local ip_pattern="^(([0-9]{1,2}|1[0-9]{2}|2([0-4][0-9]|5[0-5]))\.){3}([0-9]{1,2}|1[0-9]{2}|2([0-4][0-9]|5[0-5]))$"

    # $ip_pattern MUST NOT be quoted. Using a variable to store regex is used here to assure
    # compatiblity with pre-3.2 bash version (SLES10).
    if [[ "$test_ip" =~ $ip_pattern ]] ; then
        return 0
    else
        return 1
    fi
}

# function which get the ipv4 address from a fqdn
function get_ip_from_fqdn () {
    local fqdn=$1
    [ -z "$fqdn" ] && BugError "function get_ip_from_name() called without argument."

    # Get a list of potential IPs that resolve $fqdn
    ip=( $(getent ahostsv4 $fqdn) ) || Error "Could not resolve $fqdn to IP"
    # Check if $ip is a valide IP
    is_ip "$ip" || Error "Got '$ip' from resolving $fqdn which is not an IP"
    Log "$fqdn resolved to $ip"
    echo "$ip"
}

function linearize_interfaces_file () {
    # Transform each network_file (debian network interfaces files) into temporary one_line_interfaces file
    # for easier sed substitution.
    # ex:
    #auto eth1
    #iface eth1 inet static
    #   address 9.9.9.9
    #   netmask 255.255.255.0
    #
    # will become: auto eth1;iface eth1 inet static;address 9.9.9.9;netmask 255.255.255.0;
    interfaces_file=$1
    test -z $interfaces_file && Error "debian_linearize_interface function called without argument (file_to_migrate)"

    awk '
        /^#/ {print}
        !/^ *$/ && !/^  *$/ && !/^#/ { PRINT=1 ; gsub("^ *","") ; ITEM=ITEM $0";" }
        (/^     *$/ || /^ *$/ || /^#/ ) && PRINT==1 { print ITEM ; ITEM="" ; PRINT=0 }
        END { if( ITEM!="" ) print ITEM }
    ' < "$interfaces_file"
}

function rebuild_interfaces_file_from_linearized () {
    # recreate a Debian/ubuntu network interafces files from a linearized file (see linearize_interfaces_file).
    # It is the opposite version of linearize_interfaces_file function.

    linearized_interfaces_file=$1
    test -z $interfaces_file && Error "rebuild_interfaces_file_from_linearized function called without argument (file_to_migrate)"

    awk -F\; '
    {
        INDENT=0
        for(i=1;i<=NF;i++) {
            if ($i ~ /^iface/) {
                print $i
                INDENT=1
            }
            else {
                if (INDENT == 1) print "    "$i ; else print $i
            }
        }
    }
    ' < $linearized_interfaces_file
}

function is_persistent_ethernet_name () {
    # this function is borrowed from /usr/lib/dracut/modules.d/40network/net-lib.sh (from CentOS 7)
    local _netif="$1"
    local _name_assign_type="0"

    [ -f "/sys/class/net/$_netif/name_assign_type" ] \
        && _name_assign_type=$(cat "/sys/class/net/$_netif/name_assign_type")

    # NET_NAME_ENUM 1
    [ "$_name_assign_type" = "1" ] && return 1

    # NET_NAME_PREDICTABLE 2
    [ "$_name_assign_type" = "2" ] && return 0

    case "$_netif" in
        # udev persistent interface names
        eno[0-9]|eno[0-9][0-9]|eno[0-9][0-9][0-9]*)
            ;;
        ens[0-9]|ens[0-9][0-9]|ens[0-9][0-9][0-9]*)
            ;;
        enp[0-9]s[0-9]*|enp[0-9][0-9]s[0-9]*|enp[0-9][0-9][0-9]*s[0-9]*)
            ;;
        enP*p[0-9]s[0-9]*|enP*p[0-9][0-9]s[0-9]*|enP*p[0-9][0-9][0-9]*s[0-9]*)
            ;;
        # biosdevname
        em[0-9]|em[0-9][0-9]|em[0-9][0-9][0-9]*)
            ;;
        p[0-9]p[0-9]*|p[0-9][0-9]p[0-9]*|p[0-9][0-9][0-9]*p[0-9]*)
            ;;
        *)
            return 1
    esac
    return 0
}
