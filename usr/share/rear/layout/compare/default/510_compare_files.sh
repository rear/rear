
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
local to_be_checked
for to_be_checked in "${CHECK_CONFIG_FILES[@]}" ; do
    # Skip empty or blank elements in CHECK_CONFIG_FILES:
    test $to_be_checked || continue
    # Include all what is in directories:
    if test -d "$to_be_checked" ; then
        files_for_md5sum+=( $( find "$to_be_checked" -type f ) )
        continue
    fi
    # Include regular files and symlinks as is:
    if test -e "$to_be_checked" ; then
        files_for_md5sum+=( "$to_be_checked")
        continue
    fi
    # TODO: What about symlinks to directories?
    Log "Skip $to_be_checked in CHECK_CONFIG_FILES (no such file or directory)"
done

# Append the regenerated list of files with what is in FILES_TO_PATCH_PATTERNS:
# The patterns in FILES_TO_PATCH_PATTERNS are relative to /, change directory there
# so that the shell finds the files during pathname expansion:
pushd / >/dev/null
# The variable expansion is deliberately not quoted in order to perform
# pathname expansion on the variable value.
local to_be_patched absolute_file symlink_target
for to_be_patched in $FILES_TO_PATCH_PATTERNS ; do
    # Ensure an absolute file name is used:
    absolute_file="/$to_be_patched"
    IsInArray "$absolute_file" "${files_for_md5sum[@]}" && continue
    # Symlink handling: replace symlinks by targets (not strictly necessary, but consistent
    # with 280_migrate_uuid_tags.sh), avoid dead symlinks, and symlinks to files
    # on dynamic filesystem ( /proc etc.) - they are expected to change
    # and validating their checksums has no sense:
    if test -L "$absolute_file" ; then
        if ! symlink_target="$( readlink -e "$absolute_file" )" ; then
            LogPrint "Skip dead symlink $to_be_patched in FILES_TO_PATCH_PATTERNS"
            continue
        fi
        # If the symlink target contains /proc/ /sys/ /dev/ or /run/ we skip it because then
        # the symlink target is considered to not be a restored file that needs to be patched
        # and thus we don't need to generate and check its hash, either
        # cf. https://github.com/rear/rear/pull/2047#issuecomment-464846777
        if echo $symlink_target | egrep -q '/proc/|/sys/|/dev/|/run/' ; then
            Log "Skip $to_be_patched in FILES_TO_PATCH_PATTERNS (symlink with target $symlink_target in /proc/ /sys/ /dev/ /run/)"
            continue
        fi
    fi
    files_for_md5sum+=( "$absolute_file" )
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
    LogPrint "There are changes related to configuration files and files to be patched"
    # In the log file show the changes:
    diff -U0 <( sort $VAR_DIR/layout/config/files.md5sum ) <( sort $TMP_DIR/files.md5sum )
fi
