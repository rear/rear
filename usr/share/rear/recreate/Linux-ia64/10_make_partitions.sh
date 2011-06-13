# recreate the partitions
# install a blank default MBR on each disk

LogPrint "Creating partitions"
pushd "$VAR_DIR/recovery" >/dev/null
mkdir -p /boot
for f in $( find dev -type f -name parted ); do
	device="$(dirname "$f")"
	Log "Partitioning '${device}'"
	dd if=/dev/zero of=/${device} bs=1M count=1 >&2
	StopIfError "Could not write blank MBR onto ${device}"
	"$f"  >&2
	StopIfError "Repartioning of ${device} failed"
done
popd >/dev/null
