# #20_copy_binaries_libraries.sh
#
# copy binaries and libraries for Relax & Recover
#
#    Relax & Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax & Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax & Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

Log "Copy program files & libraries"
ProgressStart "Copy program files & libraries"
{
# calculate binaries from needed progs
declare -a BINARIES
c=0
for k in "${PROGS[@]}" "${REQUIRED_PROGS[@]}"; do
	file="$(type -p "$k")"
	if test -x "$file" ; then
		BINARIES[$c]="$file"
		let c++
		echo "Found $file"
	fi
done
} 1>&8
# copy binaries
Log "Binaries: ${BINARIES[@]}"
BinCopyTo "$ROOTFS_DIR/bin" "${BINARIES[@]}"  1>&8
ProgressStopIfError $PIPESTATUS "Could not copy binaries"

# split libs into lib and lib64 paths
# I know, our modular design demands to split this into multiple files
# but I prefer to do that when a 3rd variety has to be dealt with.
LIBS32=()
LIBS64=()
for lib in ${LIBS[@]} $(SharedObjectFiles "${BINARIES[@]}" | sed -e 's#^#/#' ) ; do
	if test "${lib/lib64\//xxxxx/}" = "$lib" ; then
		# lib64/ was NOT part of $lib
		LIBS32=( ${LIBS32[@]} $lib )
	else
		LIBS64=( ${LIBS64[@]} $lib )
	fi
done
Log "Libraries(32): ${LIBS32[@]}"
LibCopyTo "$ROOTFS_DIR/lib" ${LIBS32[@]} 1>&8 
ProgressStopIfError $PIPESTATUS "Could not copy libraries"
Log "Libraries(64): ${LIBS64[@]}"
LibCopyTo "$ROOTFS_DIR/lib64" ${LIBS64[@]} 1>&8
ProgressStopIfError $PIPESTATUS "Could not copy 64bit libraries"
ldconfig $v -r "$ROOTFS_DIR" 1>&8 
ProgressStopOrError $PIPESTATUS "Could not configure libraries with ldconfig"


