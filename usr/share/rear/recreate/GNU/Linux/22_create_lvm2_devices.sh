# Create LVM2 devices
#
# skip if the source system didn't use lvm
test -s "${VAR_DIR}/recovery/lvm/pv_list" || return

ProgressStart "Creating the LVM2 devices"

while read DEV VG UUID junk
do
	lvm pvcreate -ff -y -v --restorefile "${VAR_DIR}/recovery/lvm/vgcfgbackup.$VG" -u "${UUID}" "${DEV}" 1>&8
	ProgressStopIfError $? "Could not create PV $DEV for VG $VG"
done < "${VAR_DIR}/recovery/lvm/pv_list"
	
for vgfile in "${VAR_DIR}/recovery/lvm/"vgcfgbackup.* ; do
	VG="${vgfile##*vgcfgbackup.}"
	lvm vgcfgrestore -v --file "$vgfile" "$VG" 1>&8
	ProgressStopIfError $? "Could not restore VG configuration for '$VG'"
done

lvm vgchange -v -a y 1>&8
ProgressStopOrError $? "Could not activate VGs"

# that's it :-)
