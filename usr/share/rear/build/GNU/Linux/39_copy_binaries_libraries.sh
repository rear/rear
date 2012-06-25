# #20_copy_binaries_libraries.sh
#
# copy binaries and libraries for Relax-and-Recover
#
#    Relax-and-Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax-and-Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax-and-Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

LogPrint "Copying binaries and libraries"

# calculate binaries from needed progs
declare -a BINARIES=( $(
for bin in "${PROGS[@]}" "${REQUIRED_PROGS[@]}"; do
	file="$(get_path "$bin")"
	if [[ -x "$file" ]]; then
		echo $file
		echo "Found $file" >&8
	fi
done | sort -u) )

# copy binaries
Log "Binaries being copied: ${BINARIES[@]}"
BinCopyTo "$ROOTFS_DIR/bin" "${BINARIES[@]}" >&8
StopIfError "Could not copy binaries"

# copy libraries
declare -a all_libs=( $(
for lib in ${LIBS[@]} $(SharedObjectFiles "${BINARIES[@]}" | sed -e 's#^#/#' ) ; do
    echo $lib
done | sort -u) )

ensure_dir() {
    local dir=${1%/*}
    if [[ ! -d $ROOTFS_DIR$dir ]] ; then
        mkdir $v -p $ROOTFS_DIR$dir >&2
    fi
}

copy_lib() {
    local lib=$1

    ensure_dir $lib

    if [[ ! -e $ROOTFS_DIR/$lib ]] ; then
        cp -a -f $v $lib $ROOTFS_DIR$lib >&2
    fi
}

Log "Libraries being copied: ${all_libs[@]}"
for lib in "${all_libs[@]}" ; do
    if [[ -L $lib ]] ; then
        target=$(readlink -f $lib)
        copy_lib $target

        ensure_dir $lib
        ln $v -sf ${target} $ROOTFS_DIR$lib >&2
    else
        copy_lib $lib
    fi
done

ldconfig $v -r "$ROOTFS_DIR" >&8
StopIfError "Could not configure libraries with ldconfig"
