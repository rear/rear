# lvm2_cfg_saving script
#
#

# CHANGES
# 2007-01-03	GSS	replaced the vgcfgbackup %s solution with single vgcfgbackup calls per VG
#			because the %s didn't work on SLES10 (stupid, SLES9 had the bug, SLES9 SP3 
#			not, SLES10 has it again ...)
# 2007-01-04	GSS	Added general vgcfgbackup

# silently skip the script if lvm is not available
test -c /dev/mapper/control -a -x "$(which lvm)" || return	# silently skip

PROGS=( "${PROGS[@]}"
lvm
dmsetup
)
COPY_AS_IS=( "${COPY_AS_IS[@]}"
/etc/lvm
)
mkdir -p "${VAR_DIR}/recovery/lvm" || Error "Creating directory ${VAR_DIR}/recovery/lvm"

# first we do a general VG backup to the system default location, just in case it might be needed
vgcfgbackup 1>&2 8>/dev/null

for vg in $(lvm vgs --noheadings -o vg_name) ; do
	if IsInArray $vg "${EXCLUDE_VG[@]}" ; then
		Log "Skipping excluded volume group '$vg'"
		continue
	fi
	lvm vgcfgbackup --file "${VAR_DIR}/recovery/lvm/vgcfgbackup.$vg" $vg 1>&2 ||\
	Error "vgcfgbackup failed for '$vg': $?"
	test -s "${VAR_DIR}/recovery/lvm/vgcfgbackup.$vg" || Error "vgcfgbackup created an empty file!"
done

# truncate pv_list
echo -n "" >${VAR_DIR}/recovery/lvm/pv_list

# create pv_list, a list of PV and their VGs/UUIDs
lvm pvs -o pv_name,vg_name,pv_uuid --noheadings 8>/dev/null | while read pv vg uuid junk ; do
	# skip PV of excluded VGs
	if IsInArray  $vg "${EXCLUDE_VG[@]}" ; then
		Log "Skipping PV '$pv' of excluded VG '$vg'"
		continue
	fi
	# exclude VGs on excluded MD devices
	if IsInArray $pv "${EXCLUDE_MD[@]}" ; then
		LogPrint "Removing VG '$vg' because PV '$pv' is an excluded MD device !
YOU MUST MAKE SURE TO ALSO EXCLUDE THE CORRESPONDING MOUNT POINTS !!!"
		rm -f ${VAR_DIR}/recovery/lvm/vgcfgbackup.$vg
		continue
	fi
	echo $pv $vg $uuid >>${VAR_DIR}/recovery/lvm/pv_list
	echo $pv >>${VAR_DIR}/recovery/lvm/depends
done
# if the lvm before the while fails, then we notice it here.
test "$PIPESTATUS" -gt 0 && Error "pvs failed: $PIPESTATUS"

# test if pv_list is empty (=no LVM in use) and remove the lvm directory to reduce the confusion
# of the recovery part.
test ! -s "${VAR_DIR}/recovery/lvm/pv_list" && rm -Rf "${VAR_DIR}/recovery/lvm"
