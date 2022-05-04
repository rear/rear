
# Compare files that could have an impact on the rescue image:

# The goal is to detect all changes related to files where
# CHECK_CONFIG_FILES and FILES_TO_PATCH_PATTERNS evaluate to.
# It must also detect when CHECK_CONFIG_FILES or FILES_TO_PATCH_PATTERNS
# evaluate to different files or when it evaluates to more or less files.
# This means simple "md5sum -c < $VAR_DIR/layout/config/files.md5sum"
# cannot be used but instead the list of files must be regenerated
# (i.e. CHECK_CONFIG_FILES and FILES_TO_PATCH_PATTERNS must be evaluated)
# and their checksums must be regenerated and compared with
# what there is in VAR_DIR/layout/config/files.md5sum
# (except differences in the ordering of the files therein),
# cf. https://github.com/rear/rear/pull/2795#issuecomment-1116010676

# Nothing to do when there are no previous md5sums: 
test -s $VAR_DIR/layout/config/files.md5sum || return 0

# Regenerate the list of files for md5sum comparison:
local files_for_md5sum=()

# Regenerate the list of files from what is in CHECK_CONFIG_FILES:
local to_be_checked files_to_be_checked file_to_be_checked
for to_be_checked in "${CHECK_CONFIG_FILES[@]}" ; do
    # Skip empty or blank elements in CHECK_CONFIG_FILES:
    test $to_be_checked || continue
    # Include all what is in regular files, symlinks to regular files, directories and in symlinks to directories:
    # 'find -L' is needed to follow symbolic links which are reported as the symlink name
    # which is intended because we want to store the md5sum under its symlink name
    # because we want to also detect when the symlink changes to a different target
    # but '-type f' matches against the type of the symlink target
    # which is also intended because 'md5sum' needs regular files.
    # Dead symlinks are silenty skipped because '-type f' does not match dead symlinks
    # because for regular files and symlinks to regular files
    # 'find -L ... -type f' outputs the regular file name
    # or the symlink name provided a symlink target (of type 'f') exists:
    files_to_be_checked="$( find -L "$to_be_checked" -type f )"
    if ! test "$files_to_be_checked" ; then
        DebugPrint "Skip $to_be_checked in CHECK_CONFIG_FILES (no regular file matches)"
        continue
    fi
    # Now files_to_be_checked contains regular files and symlinks to regular files:
    for file_to_be_checked in $files_to_be_checked ; do
        # If it is a symlink and its target contains /proc/ /sys/ /dev/ or /run/ we skip it
        # because files on those filesystems are expected to change arbitrarily
        # so validating their md5sums makes no sense:
        if test -L $file_to_be_checked ; then
            symlink_target="$( readlink -e "$file_to_be_checked" )"
            if egrep -q '/proc/|/sys/|/dev/|/run/' <<< $symlink_target ; then
                DebugPrint "Skip $file_to_be_checked from CHECK_CONFIG_FILES (symlink with target $symlink_target in /proc/ /sys/ /dev/ /run/)"
                continue
            fi
        fi
        files_for_md5sum+=( "$file_to_be_checked" )
    done
done

# Append the regenerated list of files with what is in FILES_TO_PATCH_PATTERNS:
# The patterns in FILES_TO_PATCH_PATTERNS are relative to /, change directory there
# so that the shell finds the files during pathname expansion:
pushd / >/dev/null
# The variable expansion is deliberately not quoted in order to perform
# pathname expansion on the variable value.
local to_be_patched absolute_file
for to_be_patched in $FILES_TO_PATCH_PATTERNS ; do
    # Ensure an absolute file name is used:
    absolute_file="/$to_be_patched"
    # Include all what is in regular files, symlinks to regular files, directories and in symlinks to directories:
    # 'find -L' is needed to follow symbolic links which are reported as the symlink name
    # which is intended because we want to store the md5sum under its symlink name
    # because we want to also detect when the symlink changes to a different target
    # but '-type f' matches against the type of the symlink target
    # which is also intended because 'md5sum' needs regular files.
    # Dead symlinks are silenty skipped because '-type f' does not match dead symlinks
    # because for regular files and symlinks to regular files
    # 'find -L ... -type f' outputs the regular file name
    # or the symlink name provided a symlink target (of type 'f') exists:
    files_to_be_checked="$( find -L "$absolute_file" -type f )"
    if ! test "$files_to_be_checked" ; then
        DebugPrint "Skip $to_be_patched in FILES_TO_PATCH_PATTERNS (no regular file matches)"
        continue
    fi
    # Now files_to_be_checked contains regular files and symlinks to regular files:
    for file_to_be_checked in $files_to_be_checked ; do
        # Aviod duplicates (i.e. when something in CHECK_CONFIG_FILES and FILES_TO_PATCH_PATTERNS evaluate to the same):
        IsInArray "$file_to_be_checked" "${files_for_md5sum[@]}" && continue
        # If it is a symlink and its target contains /proc/ /sys/ /dev/ or /run/ we skip it
        # because files on those filesystems are expected to change arbitrarily
        # so validating their md5sums makes no sense:
        if test -L $file_to_be_checked ; then
            symlink_target="$( readlink -e "$file_to_be_checked" )"
            if egrep -q '/proc/|/sys/|/dev/|/run/' <<< $symlink_target ; then
                DebugPrint "Skip $file_to_be_checked from FILES_TO_PATCH_PATTERNS (symlink with target $symlink_target in /proc/ /sys/ /dev/ /run/)"
                continue
            fi
        fi
        files_for_md5sum+=( "$file_to_be_checked" )
    done
done
popd >/dev/null

# Regenerate the md5sums:
md5sum "${files_for_md5sum[@]}" > $TMP_DIR/files.md5sum

# Compare the regenerated md5sums with the previous md5sums
# except differences in the ordering of the md5sum files
# cf. layout/compare/default/500_compare_layout.sh
if cmp -s <( sort $VAR_DIR/layout/config/files.md5sum ) <( sort $TMP_DIR/files.md5sum ) ; then
    DebugPrint "No changes related to configuration files and files to be patched"
else
    # The 'cmp' exit status is 0 if inputs are the same, 1 if different, 2 if trouble.
    # In case of 'trouble' do the same as when the layout has changed to be on the safe side:
    LogPrintError "There are changes related to configuration files and files to be patched"
    # In the log file show the changes:
    diff -U0 <( sort $VAR_DIR/layout/config/files.md5sum ) <( sort $TMP_DIR/files.md5sum )
    # Store the latest md5sum file and move the previous one away as 'outdated'
    # so there is no longer an outdated md5sum file (e.g. from a previous "savelayout"):
    cp -p $TMP_DIR/files.md5sum $VAR_DIR/layout/config/files.md5sum.$WORKFLOW
    mv -f $VAR_DIR/layout/config/files.md5sum $VAR_DIR/layout/config/files.md5sum.outdated
    DebugPrint "The current md5sum file is $VAR_DIR/layout/config/files.md5sum.$WORKFLOW"
    DebugPrint "The old md5sum file is kept as $VAR_DIR/layout/config/files.md5sum.outdated"
fi
