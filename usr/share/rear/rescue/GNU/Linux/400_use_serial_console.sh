
DebugPrint "skipping usr/share/rear/rescue/GNU/Linux/400_use_serial_console.sh"
return 0

# Nothing to do when using serial console is not wanted:
is_true "$USE_SERIAL_CONSOLE" || return 0

KERNEL_CMDLINE=$( cmdline_add_console )
Log "Modified kernel commandline to: '$KERNEL_CMDLINE'"
