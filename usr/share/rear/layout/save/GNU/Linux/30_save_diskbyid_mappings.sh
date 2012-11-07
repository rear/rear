# Remember the mappings if any for disk-by-id

# be careful udevinfo is old, now we have udevadm
# udevinfo -r -q name -n /dev/disk/by-id/scsi-360060e8015268c000001268c000065c0-part4
# udevadm info --query=name --name /dev/disk/by-id/dm-name-vg_fedora-lv_root
UdevQueryName=""
type -p udevinfo >/dev/null && UdevQueryName="udevinfo -r -q name -n"
type -p udevadm >/dev/null && UdevQueryName="udevadm info --query=name --name"
[[ -z "$UdevQueryName" ]] && {
	LogPrint "Could not find udevinfo nor udevadm (skip diskbyid_mappings)"
	return
	}

ls /dev/disk/by-id | while read ID;
do
	ID_NEW=$($UdevQueryName /dev/disk/by-id/$ID)
	echo $ID $ID_NEW
done >$VAR_DIR/recovery/diskbyid_mappings  

[[ -f $VAR_DIR/recovery/diskbyid_mappings ]] &&  Log "Saved diskbyid_mappings"
