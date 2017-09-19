# 200_copy_binaries_libraries.sh
#
# copy binaries and libraries for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

LogPrint "Copying binaries and libraries"

# calculate binaries from needed progs
Log "Determining binaries from PROGS and REQUIRED_PROGS"
declare -a BINARIES=( $( for bin in "${PROGS[@]}" "${REQUIRED_PROGS[@]}" ; do
                             file="$( get_path "$bin" )"
                             if [[ -x "$file" ]] ; then
                                 echo $file
                                 Log "Found binary $file"
                             fi
                         done | sort -u ) )

# copy binaries
Log "Binaries being copied: ${BINARIES[@]}"
BinCopyTo "$ROOTFS_DIR/bin" "${BINARIES[@]}" >&2 || Error "Failed to copy binaries"

# copy libraries
declare -a all_libs=( $( for lib in ${LIBS[@]} $( SharedObjectFiles "${BINARIES[@]}" | sed -e 's#^#/#' ) ; do
                             echo $lib
                         done | sort -u ) )

function ensure_dir() {
    local dir=${1%/*}
    test -d $ROOTFS_DIR$dir || mkdir $v -p $ROOTFS_DIR$dir >&2
}

function copy_lib() {
    local lib=$1
    ensure_dir $lib
    test -e $ROOTFS_DIR/$lib || cp $v -a -f $lib $ROOTFS_DIR$lib >&2
}

Log "Libraries being copied: ${all_libs[@]}"
for lib in "${all_libs[@]}" ; do
    if [[ -L $lib ]] ; then
        target=$( readlink -f $lib )
        copy_lib $target
        ensure_dir $lib
        ln $v -sf $target $ROOTFS_DIR$lib >&2
    else
        copy_lib $lib
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
ldconfig $v -r "$ROOTFS_DIR" 1>&2 || LogPrintError "Configuring rescue/recovery system libraries with ldconfig failed which may casuse arbitrary failures"

