# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# copy the binaries and config files that we require to use dhclient/dhcpcd
# on the rescue image (IPv4/IPv6)

define_dhclients_variable()
{
    local x
    dhclients=()
    for x in "${DHCLIENT_BIN##*/}" \
        "${DHCLIENT6_BIN##*/}" \
        dhcpcd dhclient \
        dhcp6c dhclient6 ;
    do
        [ "x$x" == x ] && continue
        for d in ${dhclients[@]} ; do
            [ "x$d" = "x$x" ] && continue 2
        done
        dhclients=(${dhclients[@]} "$x")
    done
    dhclients=${dhclients[@]}
}

dhcp_interfaces_active() {
    local my_dhclients
    my_dhclients=${dhclients}
    my_dhclients=${dhclients// /|}
    ps -e | grep -qEs "[ /]($my_dhclients)"
    if [ $? -eq 0 ]; then
        # if we find a dhcp client being active we automatically
        # include DHCP CLIENT support in Relax-and-Recover
        Log "Running DHCP client found, enabling USE_DHCLIENT"
        USE_DHCLIENT=y
    fi
}

define_dhclient_bins()
{
    # purpuse is to define which binaries are being used on this system
    # other dhcp clients should be hard-coded in the /etc/rear/[site|local].conf file
    case ${1##*/} in
        dhcpcd) DHCLIENT_BIN=dhcpcd ;;
        dhcp6c) DHCLIENT6_BIN=dhcp6c ;;
        dhclient) DHCLIENT_BIN=dhclient ;;
        dhclient6) DHCLIENT6_BIN=dhclient6 ;;
    esac
}

##### M A I N #####
###################
# if DHCP client binaries were predefined (in the /etc/rear/local.conf file)
# we pick them up here
DHCLIENT_BIN=${DHCLIENT_BIN##*/}
DHCLIENT6_BIN=${DHCLIENT6_BIN##*/}
# following function makes an array of all known dhcp clients (more could be added)
define_dhclients_variable   # fill up array dhclients
dhcp_interfaces_active      # check if one is running (if found define USE_DHCLIENT=yes)

# suppose that we filled in variable DHCLIENT_BIN in the /etc/rear/local.conf file
# but forgot to define USE_DHCLIENT=y in the /etc/rear/local.conf file
# then we should assume that we meant USE_DHCLIENT=y instead of USE_DHCLIENT=
[ ! -z "$DHCLIENT_BIN" ] && USE_DHCLIENT=y
[ ! -z "$DHCLIENT6_BIN" ] && USE_DHCLIENT=y

# check if we defined in our site/local.conf file the variable USE_DHCLIENT
# Or, it was defined by function dhcp_interfaces_active if DHCP client was currently running
# We will always copy dhclient executables as dhcp could be activated at boot time
#[ -z "$USE_DHCLIENT" ] && return   # empty string means no dhcp client support required

# Ok, at this point we want DHCP client support to be included in the rescue
# image of Relax-and-Recover. Check which clients are available.
# Check which executables we want to include - dhcpcd or dhclient or ??
if [ -z "$DHCLIENT_BIN" ]; then
    for x in ${dhclients}
    do
        if has_binary $x; then
            define_dhclient_bins `get_path $x`
        fi
    done
fi

# we made our own /etc/dhclient.conf and /bin/dhclient-script files (no need to copy these
# from the local Linux system for dhclient). For dhcpcd we have /bin/dhcpcd.sh foreseen.
COPY_AS_IS=( "${COPY_AS_IS[@]}" "/etc/localtime" "/usr/lib/dhcpcd/*" )
PROGS=( "${PROGS[@]}" arping ipcalc usleep "${dhclients[@]}" )

# At this point we want DHCP client support and found a binary
# check if binary was defined in /etc/rear/local.conf; if not append it to rescue.conf
# as we need this variable at recovery time.
if [ ! -z "$USE_DHCLIENT" ]; then
    REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" $DHCLIENT_BIN $DHCLIENT6_BIN )
    cat - <<EOF >> "$ROOTFS_DIR/etc/rear/rescue.conf"
# The following 3 lines were added through 210_include_dhclient.sh
USE_DHCLIENT=$USE_DHCLIENT
DHCLIENT_BIN=$DHCLIENT_BIN
DHCLIENT6_BIN=$DHCLIENT6_BIN

EOF
fi

