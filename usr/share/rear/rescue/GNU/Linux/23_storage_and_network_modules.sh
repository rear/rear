# keep storage drivers for later use

# if we don't have udev then we skip this part and fall through to the old way of taking along
# all loaded modules (needed on older Linux, e.g. RHEL4)

have_udev || return 0
STORAGE_DRIVERS=(
	$(
		find /lib/modules/$KERNEL_VERSION/kernel/driver[s]/{block,firewire,ide,ata,md,message,scsi,usb/storage,virtio,xen} -type f -name \*.ko\* -printf "%f\n" | \
		sed -e 's/^\(.*\)\.ko.*/\1/'
		#  ^^^^- remove the .ko, faster one sed call than many basename calls or shell code
	)
)

# keep network drivers for later use
NETWORK_DRIVERS=(
	$(
		find /lib/modules/$KERNEL_VERSION/kernel/drivers/net -type f -name \*.ko\* -printf "%f\n" | \
		sed -e 's/^\(.*\)\.ko.*/\1/'
		#  ^^^^- remove the .ko, faster one sed call than many basename calls or shell code
	)
)

# Also include additional drivers
EXTRA_DRIVERS=(
	$(
		find /lib/modules/$KERNEL_VERSION/{extra,weak-updates} -type f -name \*.ko\* -printf "%f\n" | \
		sed -e 's/^\(.*\)\.ko.*/\1/'
		#  ^^^^- remove the .ko, faster one sed call than many basename calls or shell code
	)
)
