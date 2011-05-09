# skip if no LVM installed

type -p lvm >/dev/null || return 0

# just in case, disable LVM and MD

lvm vgchange -a n -v 1>&2 8>&- 7>&-

while read device junk ; do
	mdadm --stop /dev/$device 1>&2
	ProgressStopIfError $? "Could not stop RAID device '$device' !"
done < <(grep active /proc/mdstat)

# kick udev to deal with the changed devices
my_udevtrigger
my_udevsettle
