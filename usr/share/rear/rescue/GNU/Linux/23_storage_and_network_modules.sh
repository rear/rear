# keep storage drivers for later use
STORAGE_DRIVERS=(
	$(
		find /lib/modules/$(uname -r)/kernel/driver[s]/{ata,block,firewire,ide,md,message,scsi,usb/storage,virtio,xen} -type f -name \*.ko -printf "%f\n" | \
		sed -e 's/^\(.*\)\.ko/\1/'
		#  ^^^^- remove the .ko, faster one sed call than many basename calls or shell code
	)
)

# keep network drivers for later use
NETWORK_DRIVERS=(
	$(
		find /lib/modules/$(uname -r)/kernel/drivers/net -type f -name \*.ko -printf "%f\n" | \
		sed -e 's/^\(.*\)\.ko/\1/'
		#  ^^^^- remove the .ko, faster one sed call than many basename calls or shell code
	)
)


