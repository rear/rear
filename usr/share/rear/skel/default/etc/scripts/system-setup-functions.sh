# Use an artificial array to get the kernel command line parameters as array elements
kernel_command_line=( $( cat /proc/cmdline ) )

function rear_debug() {
    for kernel_command_line_parameter in "${kernel_command_line[@]}" ; do
        test "debug" = "$kernel_command_line_parameter" && return 0
    done
    return 1
}

function unattended_recovery() {
    for kernel_command_line_parameter in "${kernel_command_line[@]}" ; do
        test "unattended" = "$kernel_command_line_parameter" && return 0
    done
    return 1
}

function automatic_recovery() {
    # The unattended recovery mode implies automatic recovery
    # (see the implementation in skel/default/etc/scripts/run-automatic-rear)
    # so that in unattended mode the automatic recovery code must not be run
    # otherwise first the automatic recovery code and then the unattended recovery code
    # get run automatically one after the other where the unattended recovery fails
    # because for two subsequent 'rear recover' the second one fails:
    unattended_recovery && return 1
    for kernel_command_line_parameter in "${kernel_command_line[@]}" ; do
        test "auto_recover" = "$kernel_command_line_parameter" && return 0
        test "automatic" = "$kernel_command_line_parameter" && return 0
    done
    return 1
}

function set_rear_paths() {
    # In the rescue system these paths are always like this, either for real or as a symlink to the actual paths:
    CONFIG_DIR=/etc/rear
    SHARE_DIR=/usr/share/rear
    VAR_DIR=/var/lib/rear
    LOG_DIR=/var/log/rear
}

# Sources all configuration files, including default.conf, for use outside ReaR (in the startup script).
# Call set_rear_paths before calling this function.
function source_all_config() {
    # Set SECRET_OUTPUT_DEV because secret default values are set via
    #   { VARIABLE='secret value' ; } 2>>/dev/$SECRET_OUTPUT_DEV
    # cf. https://github.com/rear/rear/pull/3034#issuecomment-1691609782
    SECRET_OUTPUT_DEV="null"
    # Sourcing /usr/share/rear/conf/default.conf as we need some variables or arrays
    # E.g. UDEV_NET_MAC_RULE_FILES is used by script 55-migrate-network-devices.sh
    source $SHARE_DIR/conf/default.conf || echo -e "\n'source $SHARE_DIR/conf/default.conf' failed with exit code $?"

    # Sourcing user and rescue configuration as we need some variables
    # (EXCLUDE_MD5SUM_VERIFICATION right now and other variables in the system setup scripts):
    # The order of sourcing should be 'site' then 'local' and as last 'rescue'
    for conf in site local rescue ; do
	if test -s $CONFIG_DIR/$conf.conf ; then
            source $CONFIG_DIR/$conf.conf || echo -e "\n'source $CONFIG_DIR/$conf.conf' failed with exit code $?"
	fi
    done
}
