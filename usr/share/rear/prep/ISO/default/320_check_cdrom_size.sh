# 320_check_cdrom_size.sh
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
while read DEV total used available junk
do
	case $DEV in
	*/*)
		let available=available/1024 # convert k-blocks to MBytes
		test "${available}" -gt "${CDROM_SIZE}"
		StopIfError "Not enough space in ${ISO_DIR} [$DEV]: only ${available} MB free, need ${CDROM_SIZE} MB"
		Log "ISO Directory '${ISO_DIR}' [$DEV] has $available MB free space"
	;;
	*)
	;;
	esac
done < <(df -kP "${ISO_DIR}")
