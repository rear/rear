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
    # The unattended recovery mode implies automatic recovery (see the implementations below)
    # so that in unattended mode the automatic recovery code below must not be run
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
