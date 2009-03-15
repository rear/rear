# recreate the partitions
# install a blank default MBR on each disk

ProgressStart "Creating partitions"
pushd "$VAR_DIR/recovery" >/dev/null
test -d /boot || mkdir /boot
for f in $( find dev -type f -name parted )
do
	device="$(dirname "$f")"
	Log "Partitioning '${device}'"
	dd if=/dev/zero of=/${device} bs=1M count=1 1>&2 || \
		Error "Could not write blank MBR onto ${device}"
	ProgressStep
	"$f"  1>&2 || \
		Error "Repartioning of ${device} failed"
	ProgressStep
done
ProgressStop
popd >/dev/null
