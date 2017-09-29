# 400_copy_as_is.sh
#
# Copy files and directories that should be copied as-is into the recovery system.
# Check also for library dependencies of executables in all the copied files and
# add them to the LIBS list if they are not yet included in the copied files.

LogPrint "Copying files and directories"
Log "Files being copied: ${COPY_AS_IS[@]}"
Log "Files being excluded: ${COPY_AS_IS_EXCLUDE[@]}"

local copy_as_is_filelist_file="$TMP_DIR/copy-as-is-filelist"
local copy_as_is_exclude_file="$TMP_DIR/copy-as-is-exclude"

# Build the list of files and directories that are excluded from being copied:
local excluded_file=""
for excluded_file in "${COPY_AS_IS_EXCLUDE[@]}" ; do
    echo "$excluded_file"
done >$copy_as_is_exclude_file

# Copy files and directories as-is into the recovery system except the excluded ones and
# remember what files and directories were actually copied in a copy_as_is_filelist_file
# which is the reason that the first 'tar' must be run in verbose mode:
if ! tar -v -X $copy_as_is_exclude_file -P -C / -c "${COPY_AS_IS[@]}" 2>$copy_as_is_filelist_file | tar $v -C $ROOTFS_DIR/ -x 1>/dev/null ; then
    Error "Failed to copy files and directories in COPY_AS_IS minus COPY_AS_IS_EXCLUDE"
fi
Log "Finished copying files and directories in COPY_AS_IS minus COPY_AS_IS_EXCLUDE"

# Build an array of the actual regular files that are executable in all the copied files:
local copy_as_is_executables=()
local copy_as_is_file=""
while read -r copy_as_is_file ; do
    # Skip non-regular files (like directories and device files):
    test -f "$copy_as_is_file" || continue
    # Skip symbolic links (only care about symbolic link targets):
    test -L "$copy_as_is_file" && continue
    # Remember actual regular files that are executable:
    test -x "$copy_as_is_file" && copy_as_is_executables=( "${copy_as_is_executables[@]}" "$copy_as_is_file" )
done <$copy_as_is_filelist_file
Log "copy_as_is_executables = ${copy_as_is_executables[@]}"

# Check for library dependencies of executables in all the copied files and
# add them to the LIBS list if they are not yet included in the copied files:
Log "Adding required libraries of executables in all the copied files to LIBS"
local required_library=""
for required_library in $( RequiredSharedOjects "${copy_as_is_executables[@]}" ) ; do
    # Skip when the required library was already actually copied by 'tar' above:
    grep -q "$required_library" $copy_as_is_filelist_file && continue
    # Skip when the required library is already in LIBS:
    IsInArray "$required_library" "${LIBS[@]}" && continue
    Log "Adding required library '$required_library' to LIBS"
    LIBS=( "${LIBS[@]}" "$required_library" )
done
Log "LIBS = ${LIBS[@]}"

# Fix ReaR directories when running from checkout:
if test "$REAR_DIR_PREFIX" ; then
    Log "Fixing ReaR directories when running from checkout"
    local rear_dir=""
    for rear_dir in /usr/share/rear /var/lib/rear ; do
        ln $v -sf $REAR_DIR_PREFIX$rear_dir $ROOTFS_DIR$rear_dir 1>/dev/null
    done
fi

Log "Copying ReaR configuration directory"
# Copy ReaR configuration directory:
mkdir $v -p $ROOTFS_DIR/etc/rear
# This will do same job as lines below.
# On top of that, it does not throw log warning like:
# "cp: missing destination file operand after"
# if hidden file (.<filename>) is missing in $CONFIG_DIR
cp $v -r $CONFIG_DIR/. $ROOTFS_DIR/etc/rear/ 1>&2

