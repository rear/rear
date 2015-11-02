# 30_remove_scsi_debug_driver.sh
# if not loaded return immediately
lsmod | grep -q scsi_debug || return

rmmod scsi_debug >&2
Log "Unloaded scsi_debug device driver"
