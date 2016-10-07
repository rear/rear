# help-workflow.sh
#
# help workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

LOCKLESS_WORKFLOWS=( ${LOCKLESS_WORKFLOWS[@]} help )

function WORKFLOW_help () {

cat <<EOF
Usage: $PROGRAM [-h|--help] [-V|--version] [-dsSv] [-D|--debugscripts SET] [-c DIR] [-r KERNEL] [--] COMMAND [ARGS...]

$PRODUCT comes with ABSOLUTELY NO WARRANTY; for details see
the GNU General Public License at: http://www.gnu.org/licenses/gpl.html

Available options:
 -h --help           usage information
 -c DIR              alternative config directory; instead of /etc/rear
 -d                  debug mode; log debug messages
 -D                  debugscript mode; log every function call (via 'set -x')
 --debugscripts SET  same as -d -v -D but debugscript mode with 'set -SET'
 -r KERNEL           kernel version to use; current: '$KERNEL_VERSION'
 -s                  simulation mode; show what scripts rear would include
 -S                  step-by-step mode; acknowledge each script individually
 -v                  verbose mode; show more output
 -V --version        version information

List of commands:
EOF

for workflow in ${WORKFLOWS[@]} ; do
    description=WORKFLOW_${workflow}_DESCRIPTION
    # in some workflows WORKFLOW_${workflow}_DESCRIPTION
    # is only defined if "$VERBOSE" is set - currently (18. Nov. 2015) for those
    # WORKFLOW_savelayout_DESCRIPTION WORKFLOW_shell_DESCRIPTION WORKFLOW_udev_DESCRIPTION
    # so that an empty default is used to avoid that ${!description} is an unbound variable:
    if test -n "${!description:-}" ; then
        printf " %-16s%s\n" $workflow "${!description:-}"
    fi
done

if test -z "$VERBOSE" ; then
    echo "Use 'rear -v help' for more advanced commands."
fi

EXIT_CODE=1

}

