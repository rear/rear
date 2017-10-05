#
# ReaR networking functions.
#
# MASKS, prefix2netmask, num2ip, and get_device_by_hwaddr
# are from an old fedora-14 dhclient-script that was there
# used for DHCP setup and is still used for ReaR DHCP setup
# in skel/default/etc/scripts/dhcp-setup-functions.sh
# cf. https://github.com/rear/rear/issues/1517

readonly -a MASKS=(
        0
        2147483648 3221225472 3758096384 4026531840
        4160749568 4227858432 4261412864 4278190080
        4286578688 4290772992 4292870144 4293918720
        4294443008 4294705152 4294836224 4294901760
        4294934528 4294950912 4294959104 4294963200
        4294965248 4294966272 4294966784 4294967040
        4294967168 4294967232 4294967264 4294967280
        4294967288 4294967292 4294967294 4294967295
        -1
)

function num2ip () {
    let n="${1}"
    let o1="(n >> 24) & 0xff"
    let o2="(n >> 16) & 0xff"
    let o3="(n >> 8) & 0xff"
    let o4="n & 0xff"
    echo "${o1}.${o2}.${o3}.${o4}"
}

function prefix2netmask () {
    pf="${1}"
    echo $(num2ip "${MASKS[$pf]}")
}

function get_device_by_hwaddr () {
    LANG=C ip -o link | grep -v link/ieee802.11 | grep -i "$1" | awk -F ": " '{print $2}'
}

# Retun 0 if args is a valid IPV4 ip_address
function is_ip () {
    local test_ip=$1
    [ -z "$test_ip" ] && BugError "function is_ip() called without argument."

    # test if $test_ip is a valide IPV4 address: "[0 to 255].[0 to 255].[0 to 255].[0 to 255]"
    if [[ "$test_ip" =~ ^(([0-9]{1,2}|1[0-9]{2}|2([0-4][0-9]|5[0-5]))\.){3}([0-9]{1,2}|1[0-9]{2}|2([0-4][0-9]|5[0-5]))$ ]] ; then
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

