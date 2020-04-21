# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# copy the binaries and config files that we require to use dhclient/dhcpcd
# on the rescue image (IPv4/IPv6)

# Respect an explicit rejection
if is_false "$USE_DHCLIENT"; then
    Log "Disabling DHCP client on the rescue system (USE_DHCLIENT='$USE_DHCLIENT')"
    return 0
fi

# Array of known DHCP clients, which must also be known to skel/default/etc/scripts/system-setup.d/58-start-dhclient.sh
local dhcp_clients=(dhcpcd dhclient dhcp6c dhclient6)

# DHCLIENT_BIN, if set, specifies the DHCP client binary to use on the rescue system.
# Must be one of the binaries listed in $dhcp_clients. Default (empty): try to auto-detect.
# FIXME: DHCLIENT_BIN could be documented in default.conf as needed.
if [[ -n "$DHCLIENT_BIN" ]]; then
    has_binary "$DHCLIENT_BIN" || Error "DHCLIENT_BIN='$DHCLIENT_BIN' but such a binary could not be found"
    IsInArray "$DHCLIENT_BIN" "${dhcp_clients[@]}" || Error "DHCLIENT_BIN='$DHCLIENT_BIN' is not among known DHCP clients (${dhcp_clients[*]})"
fi


function dhcp_client_is_active() {
    # Strategy 1: Check if any DHCP client process is running (does not need to be the one specified by DHCLIENT_BIN)
    local dhcp_clients_regexp="${dhcp_clients[*]}"
    dhcp_clients_regexp=${dhcp_clients_regexp// /|}
    if ps -e | grep -qEs "[ /]($dhcp_clients_regexp)"; then
        Log "Detected an active DHCP client process"
        return 0
    fi

    # Strategy 2: Check if systemd-networkd is active and configured to use its built-in DHCP client
    if type systemctl &>/dev/null && systemctl is-active --quiet systemd-networkd; then
        # Check the systemd.network(5) configuration for an effective configuration file enabling DHCP
        # for some network interface. Configuration files live in {/etc,/run,/lib}/systemd/network/*.network and
        # systemd configuration file priorities apply. Note that we do not check for additional *.conf files in
        # "drop-in" directories (*.network.d) as this would add an additional layer of complexity.
        # (Life could be easier if there was something like 'systemctl show *.network', but there isn't yet.)
        local config_bases=(/etc /run /lib)  # priority: high to low
        local config_files=()  # relative paths to config bases
        local config_base config_file

        # Read relative config file paths into the 'config_files' array variable (safe in case of blanks).
        while IFS='' read -r config_file; do
            config_files+=("$config_file")
        done < <(
            for config_base in "${config_bases[@]}"; do
                (cd "$config_base" && find systemd/network -name '*.network' -print)
            done | sort -u
        )

        # Determine the list of active network interface devic names.
        local ip_device_regexp="$(ip link show | awk -F '[: ]+' '/state UP/ { printf("%s%s", sep, $2); sep="|"; }')"

        for config_file in "${config_files[@]}"; do
            for config_base in "${config_bases[@]}"; do
                if [[ -r "$config_base/$config_file" ]]; then
                    # Check only configuration files matching an active network interface devic name. (Note:
                    # configuration files allow other types of matching, which is ignored here for simplicity.)
                    if grep -Eq "^[[:space:]]*Name[[:space:]]*=[[:space:]]*($ip_device_regexp)[[:space:]]*$" "$config_base/$config_file"; then
                        # Check if DHCP is enabled for an interface.
                        if grep -Eq '^[[:space:]]*DHCP[[:space:]]*=[[:space:]]*(yes|ip)' "$config_base/$config_file"; then
                            Log "Detected an active systemd-networkd configured to use its built-in DHCP client"
                            return 0
                        fi
                    fi
                    break  # do not consider lower-priority config files
                fi
            done
        done
    fi

    return 1
}


# Enable DHCP on the rescue system if reasonable
if is_true "$USE_DHCLIENT"; then
    Log "Enabling DHCP on the rescue system (USE_DHCLIENT='$USE_DHCLIENT')"
elif dhcp_client_is_active; then
    USE_DHCLIENT=y
    Log "Auto-enabling DHCP on the rescue system"
elif [[ -n "$DHCLIENT_BIN" ]]; then
    # explicitly configured DHCLIENT_BIN but forgot to set USE_DHCLIENT=y
    USE_DHCLIENT=y
    Log "Enabling DHCP on the rescue system (DHCLIENT_BIN='$DHCLIENT_BIN')"
fi


if is_true "$USE_DHCLIENT"; then
    # Set DHCLIENT_BIN if not already done
    if [[ -z "$DHCLIENT_BIN" ]]; then
        local dhclient_bin
        for dhclient_bin in "${dhcp_clients[@]}" ; do
            if has_binary "$dhclient_bin"; then
                DHCLIENT_BIN="$dhclient_bin"
                break
            fi
        done

        if [[ -z "$DHCLIENT_BIN" ]]; then
            Error "DHCP is enabled but no DHCP client binary (${dhcp_clients[*]}) was found"
        fi
    fi

    REQUIRED_PROGS+=( "$DHCLIENT_BIN" )

    # Append variables to rescue.conf to configure DHCP on the rescue system:
    cat - <<EOF >> "$ROOTFS_DIR/etc/rear/rescue.conf"
# The following 2 lines were added by 210_include_dhclient.sh
USE_DHCLIENT=$USE_DHCLIENT
DHCLIENT_BIN=$DHCLIENT_BIN

EOF
fi


# Even if DHCP is still not enabled, we will still copy dhclient executables
# as DHCP could be activated manually on the rescue system.
# We made our own /etc/dhclient.conf and /bin/dhclient-script files (no need to copy these
# from the local Linux system for dhclient). For dhcpcd we have /bin/dhcpcd.sh foreseen.
COPY_AS_IS+=( "/etc/localtime" "/usr/lib/dhcpcd/*" )
PROGS+=( arping ipcalc usleep "${dhcp_clients[@]}" )
