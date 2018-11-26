# 200_copy_binaries_libraries.sh
#
# Copy binaries and libraries for Relax-and-Recover.
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Local functions that are 'unset' at the end of this script:

# Copy binaries given in $2 $3 ... to directory $1.
# A leading path of the binaries is not copied.
function copy_binaries () {
    local destdir="$1"
    test -d "$destdir" || BugError "copy_binaries destination '$destdir' is not a directory"
    local binary=""
    while (( $# > 1 )) ; do
        shift
        binary="$1"
        # Continue with the next one if a binary is empty or contains only blanks:
        contains_visible_char "$binary" || continue
        if ! cp $verbose --archive --dereference --force "$binary" "$destdir" 1>&2 ; then
            Error "Failed to copy '$binary' to '$destdir'"
        fi
    done
}

# Create missing directory components of a filename with path in $1:
function create_missing_dirs () {
    # Use dirname because in contrast to bash parameter expansion via ${1%/*}
    # dirname works even for multiple slash characters as in /path/to///file
    # and also for trailing slash characters as in /path/to///file///
    # (where 'dirname /path/to///file///' results '/path/to'):
    local dir=$( dirname $1 )
    test -d $ROOTFS_DIR/$dir || mkdir $v -p $ROOTFS_DIR/$dir 1>&2
}

# Copy library given in $1 with creating directory components as needed:
function copy_lib () {
    local lib=$1
    create_missing_dirs $lib
    test -e $ROOTFS_DIR/$lib || cp $v -a -f $lib $ROOTFS_DIR/$lib 1>&2
}

# Start of the actual work:
LogPrint "Copying binaries and libraries"

# Calculate binaries from needed progs:
Log "Determining binaries from PROGS and REQUIRED_PROGS"
local bin=""
local bin_path=""
local all_binaries=( $( for bin in "${PROGS[@]}" "${REQUIRED_PROGS[@]}" ; do
                            bin_path="$( get_path "$bin" )"
                            if test -x "$bin_path" ; then
                                echo $bin_path
                                Log "Found binary $bin_path"
                            fi
                        done | sort -u ) )

# Copy binaries:
Log "Binaries being copied: ${all_binaries[@]}"
# No need to check for errors here because copy_binaries already errors out:
copy_binaries "$ROOTFS_DIR/bin" "${all_binaries[@]}"

# Copy libraries:
# It is crucial to also have all LIBS itself in all_libs because RequiredSharedObjects()
# outputs only those libraries that are required by a library but not the library itself
# so that without all LIBS itself in all_libs those libraries in LIBS are missing that
# are not needed by a binary in all_binaries (all_binaries were already copied above).
# RequiredSharedObjects outputs the required shared objects on STDOUT.
# The output are absolute paths to the required shared objects.
# The output can also be symbolic links (also as absolute paths).
# In case of symbolic links only the link but not the link target is output.
# Therefore for symbolic links also the link target gets copied below.
local all_libs=( "${LIBS[@]}" $( RequiredSharedObjects "${all_binaries[@]}" "${LIBS[@]}" ) )

Log "Libraries being copied: ${all_libs[@]}"
local lib=""
local link_target=""
for lib in "${all_libs[@]}" ; do
    if test -L $lib ; then
        # Because $lib is a symbolic link on the original system
        # all of its link target components must exist so that 'readlink -e' is used.
        # Otherwise report that there is something wrong on the original system and
        # assume when things work sufficiently on the original system nevertheless
        # this is no sufficient reason to abort here (i.e. proceed "bona fide"):
        link_target=$( readlink -e $lib )
        if test "$link_target" ; then
            copy_lib $link_target || LogPrintError "Failed to copy symlink target '$link_target'"
            # If in the original system there was a chain of symbolic links like
            #   /some/path/to/libfoo.so.1 -> /another/path/to/libfoo.so.1.2 -> /final/path/to/libfoo.so.1.2.3
            # where $lib='/some/path/to/libfoo.so.1' and $link_target='/final/path/to/libfoo.so.1.2.3'
            # the chain of symbolic links gets simplified in the recovery system to $lib -> $link_target like
            #   /some/path/to/libfoo.so.1 -> /final/path/to/libfoo.so.1.2.3
            create_missing_dirs $lib || LogPrintError "Failed to create directories of symlink '$lib'"
            ln $v -sf $link_target $ROOTFS_DIR/$lib 1>&2 || LogPrintError "Failed to link '$link_target' as symlink '$lib'"
        else
            LogPrintError "Cannot copy symlink '$lib' because 'readlink' cannot determine its link target"
        fi
    else
        copy_lib $lib || LogPrintError "Failed to copy '$lib'"
    fi
done

# Run ldconfig for the libraries in the recovery system
# to get the libraries configuration in the recovery system consistent as far as possible
# because an inconsistent libraries configuration in the recovery system could even cause
# that the recovery system fails to boot with kernel panic because init fails
# when a library is involved where init is linked with, for example see
# https://github.com/rear/rear/issues/1494
# In case of ldconfig errors report it but do not treat it as fatal (i.e. do not Error out)
# because currently it is sometimes not possible to get a consistent libraries configuration
# and usually (i.e. unless one has an unusual special libraries configuration)
# even an inconsistent libraries configuration works sufficiently, for example see
# https://github.com/rear/rear/issues/772
# TODO: Get the libraries configuration in the recovery system consistent in any case.
ldconfig $v -r "$ROOTFS_DIR" 1>&2 || LogPrintError "ldconfig failed to configure rescue/recovery system libraries which may cause arbitrary failures"

# Local functions must be 'unset' because bash does not support 'local function ...'
# cf. https://unix.stackexchange.com/questions/104755/how-can-i-create-a-local-function-in-my-bashrc
unset -f copy_binaries
unset -f create_missing_dirs
unset -f copy_lib

