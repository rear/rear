# 270_overrule_migration_mode.sh
# Tricky script where we overrule the variable MIGRATION_MODE if it was set to true
# This means that rear recover could fail because of disk size mismatches, but we give it try
# The 'unattended' parameter must be present on the boot command line - for the moment
# this feature will only be used by automated PXE booting

for kernel_command_line_parameter in $( cat /proc/cmdline ) ; do
    if test "unattended" = "$kernel_command_line_parameter" ; then
        LogPrint "Switching off migration mode due to 'unattended' kernel option"
        MIGRATION_MODE=
        return
    fi
done

