# Recreate some directories/symlinks in the rescue system if present.
# Eventually more stuff from $SHARE_DIR/skel could be moved here.
# The main use is for symlinks, as their presence in the source tree
# (under $SHARE_DIR/skel) brings some problems.
# See https://docs.fedoraproject.org/en-US/packaging-guidelines/Directory_Replacement/

# Other file types can be copied using this mechanism,
# but it is probably better to use the COPY_AS_IS variable for them.
# For a directory the difference is that COPY_AS_IS would copy it recursively,
# while this mechanism recreates the directory as empty.

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

local skeleton_paths=( /var/run )

local skel_path
local existing_skeleton_paths=()

# some checks before copying
for skel_path in "${skeleton_paths[@]}" ; do
    if ! [ -e "$skel_path" ] ; then
        Debug "Skeleton path '$skel_path' not present, not creating it under $ROOTFS_DIR"
        # tar would complain if given a nonexistent path, skip it
        continue
    fi

    # We could of course replace it, but this should not happen,
    # so erroring out is safer
    [ -e "$ROOTFS_DIR/$skel_path" ] && BugError "'$ROOTFS_DIR/$skel_path' already exists - remove '$skel_path' from $SHARE_DIR/skel if it is present there"

    # we want relative paths to avoid superfluous
    # "Removing leading `/' from member names" message from tar
    existing_skeleton_paths+=( "./$skel_path" )
done

# no-recursion because we are interested in the directory itself and not its contents
tar -f - --no-recursion -C / -c "${existing_skeleton_paths[@]}" | tar -f - -C "$ROOTFS_DIR" -x || Error "Failed to copy some of '${existing_skeleton_paths[*]}' to $ROOTFS_DIR"

# Restore the ReaR default bash flags and options
# from "set -e -u -o pipefail" (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"
