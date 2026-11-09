# 500_restore_saved_layout.sh

# With COH_RESTORE_SAVED_LAYOUT enabled, the administrator restores this
# client's own disk layout (saved by 'rear savelayout' and included in the
# Cohesity backup) from the Cohesity Data Cloud console, and it is used
# instead of the layout baked into a generic recovery image.
# Runs after the Cohesity agent was started so the cluster can reach it,
# and before layout/prepare reads the layout.

is_true "$COH_RESTORE_SAVED_LAYOUT" || return 0

local coh_saved_dir="$TMP_DIR/coh_saved_layout"
local coh_layout_dir="$VAR_DIR/layout"
local coh_layout_file=""
local coh_saved_layout_dir=""
local coh_choice=""

rm -rf $coh_saved_dir
mkdir -p $coh_saved_dir || Error "Cannot create $coh_saved_dir."

while true ; do
    UserOutput "
Restore the saved disk layout of this client now.

In the Cohesity Data Cloud console (or via its REST API) start a Physical Server
File & Folder recovery of this host. Select the folder $coh_layout_dir for
restore. It must contain a disklayout.conf file.

Restore the data into: $coh_saved_dir

The restored files can end up in a subdirectory of that path. Wait until the
Cohesity recovery job has finished and press ENTER to verify the restored disk
layout. Type 'exit' to abort the recovery.
"
    coh_choice="$( UserInput -I COH_SAVED_LAYOUT_RESTORE -t 0 -D 'check' )"
    if test "$coh_choice" = "exit" ; then
        Error "Aborted by the user, the saved disk layout was not restored. Set COH_RESTORE_SAVED_LAYOUT=false to use the disk layout of this recovery image instead."
    fi
    # The critical file must exist and not be empty.
    coh_layout_file="$( find $coh_saved_dir -type f -name disklayout.conf -size +0 2>/dev/null | head -n1 )"
    if test -n "$coh_layout_file" ; then
        break
    fi
    UserOutput ""
    UserOutput "ERROR: disklayout.conf was not found under $coh_saved_dir. Check the Cohesity recovery job and try again."
done

coh_saved_layout_dir="$( dirname $coh_layout_file )"

# Replace the layout of the generic image by the saved one.
cp -a $coh_saved_layout_dir/disklayout.conf $coh_layout_dir/disklayout.conf || Error "Cannot copy the saved disklayout.conf to $coh_layout_dir."
if test -d $coh_saved_layout_dir/config ; then
    mkdir -p $coh_layout_dir/config
    cp -a $coh_saved_layout_dir/config/. $coh_layout_dir/config/ || Error "Cannot copy the saved layout/config files to $coh_layout_dir/config."
fi
UserOutput "Using the restored disk layout from the Cohesity backup for the recovery."
