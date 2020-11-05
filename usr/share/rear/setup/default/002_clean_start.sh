# Ensure we start from a known-clean initial state.
# E.g. request reboot before launching another workflow if 'mountonly' has
# been run already, except in certain cases.
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Define our breadcrumb
BREADCRUMB="$VAR_DIR/last_run_workflow"
local last_run=""

if test -r "$BREADCRUMB"; then
    last_run=`cat $BREADCRUMB`
    case $last_run in
        mountonly)
            case $WORKFLOW in
                restoreonly|finalizeonly)
                    # allowed sequence of subsequent workflows after 'mountonly' was run
                    ;;
                *)
                    Error "The '$last_run' workflow was run. Disk state no longer clean. Reboot to run '$WORKFLOW' from clean disk state."
                    ;;
            esac
    esac
fi
