# 270_overrule_migration_mode.sh
# Tricky script where we overrule the variable MIGRATION_MODE if it was set to true.
# This means that rear recover could fail because of disk size mismatches, but we give it try.
# The 'unattended' parameter must be present on the boot command line - for the moment
# this feature will only be used by automated PXE booting.

# Nothing to do unless MIGRATION_MODE has a 'true' value:
is_true "$MIGRATION_MODE" || return 0

for kernel_command_line_parameter in $( cat /proc/cmdline ) ; do
    if test 'unattended' = "$kernel_command_line_parameter" ; then
        # In etc/rear/local.conf or via layout/prepare/default/250_compare_disks.sh the user may have
        # enforced MIGRATION_MODE by setting the special 'TRUE' value in upper case letters
        # that overrules switching off migration mode due to 'unattended' kernel option:
        if test 'TRUE' = "$MIGRATION_MODE" ; then
            LogPrint "User enforced manual disk layout configuration overrules 'unattended' recovery"
            return
        fi
        LogPrint "Switching off manual disk layout configuration (MIGRATION_MODE) due to 'unattended' kernel option"
        MIGRATION_MODE='false'
        return
    fi
done

