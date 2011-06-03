# skip if no LVM installed

if ! type -p lvm >/dev/null; then
    return 0
fi

# just in case, disable LVM and MD

lvm vgchange -a n -v 1>&2
LogIfError "Error $? while disabling lvm"
sleep 1
if lvm lvs --noheadings --options Attr | grep -q a ; then
	Log "Some LVs are still active after deactivating LVM"
	lvm lvs 1>&2
	BugError "There are still some LVs active after deactivating LVM"
fi

while read device junk ; do
	mdadm --stop /dev/$device 1>&2
	StopIfError "Could not stop RAID device '$device' !"
done < <(grep active /proc/mdstat)

