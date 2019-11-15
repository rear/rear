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
                    # allowed sequence
                    ;;
                *)
                    Error "The '$last_run' workflow has already run in this session. Slate no longer clean. Please reboot before calling workflow '$WORKFLOW'!"
                    ;;
            esac
    esac
fi
