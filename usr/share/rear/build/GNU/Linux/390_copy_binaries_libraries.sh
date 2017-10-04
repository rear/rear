# 200_copy_binaries_libraries.sh
#
# Copy binaries and libraries for Relax-and-Recover.
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

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
BinCopyTo "$ROOTFS_DIR/bin" "${all_binaries[@]}" 1>&2 || Error "Failed to copy binaries"

# Copy libraries:
# It is crucial to also have all LIBS itself in all_libs because RequiredSharedOjects()
# outputs only those libraries that are required by a library but not the library itself
# so that without all LIBS itself in all_libs those libraries in LIBS are missing that
# are not needed by a binary in all_binaries (all_binaries were already copied above).
# RequiredSharedOjects outputs the required shared objects on STDOUT.
# The output are absolute paths to the required shared objects.
# The output can also be symbolic links (also as absolute paths).
# In case of symbolic links only the link but not the link target is output.
# Therefore for symbolic links also the link target gets copied below.
local all_libs=( "${LIBS[@]}" $( RequiredSharedOjects "${all_binaries[@]}" "${LIBS[@]}" ) )

function ensure_dir() {
    local dir=${1%/*}
    test -d $ROOTFS_DIR/$dir || mkdir $v -p $ROOTFS_DIR/$dir 1>&2
}

function copy_lib() {
    local lib=$1
    ensure_dir $lib
    test -e $ROOTFS_DIR/$lib || cp $v -a -f $lib $ROOTFS_DIR/$lib 1>&2
}

Log "Libraries being copied: ${all_libs[@]}"
local lib=""
local link_target=""
for lib in "${all_libs[@]}" ; do
    if test -L $lib ; then
        # None of the link target components may already exist when 'readlink' is called
        # because they could be first created by the subsequent 'copy_lib $link_target'
        # so that 'readlink -m' must be used:
        link_target=$( readlink -m $lib )
        if test "$link_target" ; then
            copy_lib $link_target || LogPrintError "Failed to copy symlink target '$link_target'"
            # If in the original system there was a chain of symbolic links like
            #   /some/path/to/libfoo.so.1 -> /another/path/to/libfoo.so.1.2 -> /final/path/to/libfoo.so.1.2.3
            # it gets simplified in the recovery system to
            #   /some/path/to/libfoo.so.1 -> /final/path/to/libfoo.so.1.2.3
            ensure_dir $lib || LogPrintError "Failed to create directories of symlink '$lib'"
            ln $v -sf $link_target $ROOTFS_DIR/$lib 1>&2 || LogPrintError "Failed to link '$link_target' as symlink '$lib'"
        else
            LogPrintError "Cannot copy symlink '$lib' because it has no link target"
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
ldconfig $v -r "$ROOTFS_DIR" 1>&2 || LogPrintError "ldconfig failed to configure rescue/recovery system libraries which may casuse arbitrary failures"

