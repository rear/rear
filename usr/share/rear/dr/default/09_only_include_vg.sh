# 10_only_include_vg.sh script
# In /etc/rear/default.conf file we find a variable called EXCLUDE_VG[@]
# On bigger systems, e.g. with SAP, there may be many VGs we want to exclude
# Therefore we introduced the mutual exclusive include VG, e.g. vg00
# When ONLY_INCLUDE_VG[@] is set we automatically populate the EXCLUDE_VG[@]
# and the corresponding EXCLUDE_MOUNTPOINTS[@] array
#
# Author: GD - 16/Dec/2008
#

test ${#ONLY_INCLUDE_VG[@]} -eq 0 && return	# skip when ONLY_INCLUDE_VG is empty

# write the known VGs on this system into file $TMP_DIR/known_vg
lvm vgs --noheadings -o vg_name 2>&8 8>&- 7>&- | awk '{print $1}' | sort > $TMP_DIR/known_vg

# list the ONLY_INCLUDE_VG[@] array into file $TMP_DIR/include_vg
echo ${ONLY_INCLUDE_VG[@]} | tr ' ' '\n' | sort -u > $TMP_DIR/include_vg

# build up the EXCLUDE_VG array with excluding the include_vg file as input (option -v)
for vg in `grep -f $TMP_DIR/include_vg -v $TMP_DIR/known_vg`; do
	EXCLUDE_VG=( "${EXCLUDE_VG[@]}" "${vg}" )
done

test ${#EXCLUDE_VG[@]} -eq 0 && return		# EXCLUDE_VG is empty, silently return

Log "Excluded Volume Group(s) : " "${EXCLUDE_VG[@]}"

# list up the mountpoints to exclude
#EXCLUDE_MOUNTPOINTS=( )
for vg in `echo "${EXCLUDE_VG[@]}"`; do
	for fs in `mount | grep "${vg}" | awk '{print $3}'` ; do
		EXCLUDE_MOUNTPOINTS=( "${EXCLUDE_MOUNTPOINTS[@]}" "${fs}" )
	done
done
Log "Excluded Mount Points : " "${EXCLUDE_MOUNTPOINTS[@]}"
# save a copy of file systems to be excluded from restore (e.g. with an external solution)
if test ${#EXCLUDE_MOUNTPOINTS[@]} -gt 0 ; then
	echo "${EXCLUDE_MOUNTPOINTS[@]}" | tr ' ' '\n' | sort -u > $VAR_DIR/recovery/exclude_mountpoints
fi

true
