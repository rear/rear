# help-workflow.sh
#
# help workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

LOCKLESS_WORKFLOWS+=( help )

function WORKFLOW_help () {

# Do nothing in simulation mode, cf. https://github.com/rear/rear/issues/1939
if is_true "$SIMULATE" ; then
    LogPrint "${BASH_SOURCE[0]} outputs usage information"
    return 0
fi

# Output the help text to the original STDOUT but keep STDERR in the log file:
cat 1>&7 <<EOF
Usage: $PROGRAM [-h|--help] [-V|--version] [-dsSv] [-D|--debugscripts SET] [-c DIR] [-C CONFIG] [-r KERNEL] [--] COMMAND [ARGS...]

$PRODUCT comes with ABSOLUTELY NO WARRANTY; for details see
the GNU General Public License at: http://www.gnu.org/licenses/gpl.html

Available options:
 -h --help           usage information (this text)
 -c DIR              alternative config directory; instead of /etc/rear
 -C CONFIG           additional config file; absolute path or relative to config directory
 -d                  debug mode; log debug messages (also sets -v verbose mode)
 -D                  debugscript mode (implies -v -d); log executed commands (via 'set -x')
 --debugscripts SET  same as -d -v -D but debugscript mode with 'set -SET'
 -r KERNEL           kernel version to use; current: '$KERNEL_VERSION'
 -s                  simulation mode; show what scripts are run (without executing them)
 -S                  step-by-step mode; acknowledge each script individually
 -v                  verbose mode; show more output (and run many commands in verbose mode)
 -V --version        version information

List of commands:
EOF

# Output all workflow descriptions of the currently usable workflows
# to the original STDOUT but keep STDERR in the log file:
currently_usable_workflows="${WORKFLOWS[@]}"
# See init/default/050_check_rear_recover_mode.sh what the usable workflows are in the ReaR rescue/recovery system.
# In the ReaR rescue/recovery system /etc/rear-release is unique (it does not exist otherwise):
test -f /etc/rear-release && currently_usable_workflows="recover layoutonly restoreonly finalizeonly mountonly opaladmin help"
for workflow in $currently_usable_workflows ; do
    description_variable_name=WORKFLOW_${workflow}_DESCRIPTION
    # in some workflows WORKFLOW_${workflow}_DESCRIPTION
    # is only defined if "$VERBOSE" is set - currently (23. Oct. 2018) for those
    # WORKFLOW_savelayout_DESCRIPTION WORKFLOW_shell_DESCRIPTION WORKFLOW_udev_DESCRIPTION
    # WORKFLOW_layoutonly_DESCRIPTION WORKFLOW_finalizeonly_DESCRIPTION
    # so that an empty default is used to avoid that ${!description_variable_name} is an unbound variable:
    test "${!description_variable_name:-}" && printf " %-16s%s\n" $workflow "${!description_variable_name:-}"
done 1>&7

# Output the text to the original STDOUT but keep STDERR in the log file:
test "$VERBOSE" || echo "Use 'rear -v help' for more advanced commands." 1>&7

}

