# 400_copy_as_is.sh
#
# Copy files and directories that should be copied as-is into the recovery system.
# Check also for library dependencies of executables in all the copied files and
# add them to the LIBS list if they are not yet included in the copied files.

LogPrint "Copying files and directories"

# Filter out duplicate entries in COPY_AS_IS but keep the ordering of the elements
# (i.e. only the first occurrence of an element is kept)
# cf. https://github.com/rear/rear/issues/2377
local copy_as_is_without_duplicates=()
# The basic deduplication algorithm that is used here is to 'printf' each COPY_AS_IS element
# on a separated line (i.e. this algorithm fails when elements contain newline characters)
# and then filter those lines by 'awk' that outputs only the first occurrence of a line.
# To remove duplicate lines and keep the ordering one could use ... | cat -n | sort -uk2 | sort -nk1 | cut -f2-
# cf. https://stackoverflow.com/questions/11532157/remove-duplicate-lines-without-sorting/11532197#11532197
# that also explains an awk command that prints each line provided the line was not seen before.
# The awk variable $0 holds an entire line and square brackets is associative array access in awk.
# For each line the node of the associative array 'seen' is incremented and the line is printed
# if the content of that node was not '!' previously set (i.e. if the line was not previously seen)
# cf. https://www.thegeekstuff.com/2010/03/awk-arrays-explained-with-5-practical-examples/
{ while read line ; do
    # A new temporary array is used to store the deduplicated elements for two reasons:
    # I <jsmeix@suse.de> found no way how to do rewrite COPY_AS_IS in one command
    # that also works reliably with spaces or special characters in the elements and
    # the intermediate array is used to test if the deduplication result looks right:
    copy_as_is_without_duplicates+=( "$line" )
  done < <( printf '%s\n' "${COPY_AS_IS[@]}" | awk '!seen[$0]++' )
} 2>>/dev/$DISPENSABLE_OUTPUT_DEV
# If the deduplication result does not looks reasonable keep using the unchanged COPY_AS_IS
# also keep using the unchanged COPY_AS_IS when there was no duplicate element
# which avoids a useless copy of the copy_as_is_without_duplicates array to COPY_AS_IS.
# The hardcoded condition that copy_as_is_without_duplicates contains more than 100 elements
# is based on the finding that usually COPY_AS_IS has about 130 elements without duplicates
# cf. https://github.com/rear/rear/issues/2377#issuecomment-618301702
# so if deduplication results less than 100 elements things look fishy (possibly falsely removed elements)
# and then we fall back using the original COPY_AS_IS because things still work
# when we let 'tar' needlessly copy duplicated things several times:
if test ${#copy_as_is_without_duplicates[@]} -gt 100 -a ${#COPY_AS_IS[@]} -gt ${#copy_as_is_without_duplicates[@]} ; then
    Log "COPY_AS_IS has ${#COPY_AS_IS[@]} elements with duplicates"
    # The simplest way to copy a non-associative array in bash is COPY=( "$ARRAY[@]" )
    # but it will compress a sparse array and re-index an array with non-contiguous indices e.g.
    #   # arr=( zero one two three )
    #   # unset arr[0] arr[2]
    #   # declare -p arr
    #   declare -a arr=([1]="one" [3]="three")
    #   # arr2=( "${arr[@]}" )
    #   # declare -p arr2
    #   declare -a arr2=([0]="one" [1]="three")
    # which is even an advantage when COPY_AS_IS gets re-indexed (without changing its ordering)
    # cf. https://stackoverflow.com/questions/19417015/how-to-copy-an-array-in-bash
    COPY_AS_IS=( "${copy_as_is_without_duplicates[@]}" )
    Log "COPY_AS_IS has ${#COPY_AS_IS[@]} elements without duplicates"
fi

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
# which is the reason that the first 'tar' must be run in verbose mode.
# Symbolic links must be copied as symbolic links ('tar -h' must not be used here)
# because 'tar -h' does not finish and blows up the recovery system to Gigabytes,
# see https://github.com/rear/rear/pull/1636
# It is crucial that pipefail is not set (cf. https://github.com/rear/rear/issues/700)
# to make it work fail-safe even in case of non-existent files in the COPY_AS_IS array because
# in case of non-existent files 'tar' is "Exiting with failure status" like in the following example:
#  # echo foo >foo ; echo baz >baz ; tar -cvf archive.tar foo bar baz ; echo $? ; tar -tvf archive.tar
#  foo
#  tar: bar: Cannot stat: No such file or directory
#  baz
#  tar: Exiting with failure status due to previous errors
#  2
#  -rw-r--r-- root/root         4 2017-10-12 11:31 foo
#  -rw-r--r-- root/root         4 2017-10-12 11:31 baz
# Because pipefail is not set it is the second 'tar' in the pipe that determines whether or not the whole operation was successful:
if ! tar -v -X $copy_as_is_exclude_file -P -C / -c "${COPY_AS_IS[@]}" 2>$copy_as_is_filelist_file | tar $v -C $ROOTFS_DIR/ -x 1>/dev/null ; then
    Error "Failed to copy files and directories in COPY_AS_IS minus COPY_AS_IS_EXCLUDE"
fi
Log "Finished copying files and directories in COPY_AS_IS minus COPY_AS_IS_EXCLUDE"

# Build an array of the actual regular files that are executable in all the copied files:
local copy_as_is_executables=()
local copy_as_is_file=""
# It is crucial to append to /dev/$DISPENSABLE_OUTPUT_DEV (cf. 'Print' in lib/_input-output-functions.sh):
while read -r copy_as_is_file ; do
    # Skip non-regular files like directories, device files, and 'tar' error messages (e.g. in case of non-existent files, see above):
    test -f "$copy_as_is_file" || continue
    # Skip symbolic links (only care about symbolic link targets):
    test -L "$copy_as_is_file" && continue
    # Remember actual regular files that are executable:
    test -x "$copy_as_is_file" && copy_as_is_executables+=( "$copy_as_is_file" )
done < <( sort -u $copy_as_is_filelist_file ) 2>>/dev/$DISPENSABLE_OUTPUT_DEV
Log "copy_as_is_executables = ${copy_as_is_executables[@]}"

# Check for library dependencies of executables in all the copied files and
# add them to the LIBS list if they are not yet included in the copied files:
Log "Adding required libraries of executables in all the copied files to LIBS"
local required_library=""
# It is crucial to append to /dev/$DISPENSABLE_OUTPUT_DEV (cf. 'Print' in lib/_input-output-functions.sh):
for required_library in $( RequiredSharedObjects "${copy_as_is_executables[@]}" ) ; do
    # Skip when the required library was already actually copied by 'tar' above.
    # grep for a full line (copy_as_is_filelist_file contains 1 file name per line)
    # to avoid that libraries get skipped when their library path is a substring
    # of another already copied library, e.g. do not skip /path/to/lib when
    # /other/path/to/lib was already copied, cf. https://github.com/rear/rear/pull/1976
    grep -q "^${required_library}\$" $copy_as_is_filelist_file && continue
    # Skip when the required library is already in LIBS:
    IsInArray "$required_library" "${LIBS[@]}" && continue
    Log "Adding required library '$required_library' to LIBS"
    LIBS+=( "$required_library" )
done 2>>/dev/$DISPENSABLE_OUTPUT_DEV
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
# if hidden file (.<filename>) is missing in $CONFIG_DIR.
# To avoid dangling symlinks copy the content of the symlink target via '-L'
# which could lead to same content that exists in two independent regular files but
# for configuration files there is no other option than copying dereferenced files
# since files in $CONFIG_DIR specified with '-c /path' get copied into '/etc/rear'
# in the ReaR recovery system, cf. https://github.com/rear/rear/issues/1923
cp $v -r -L $CONFIG_DIR/. $ROOTFS_DIR/etc/rear/

