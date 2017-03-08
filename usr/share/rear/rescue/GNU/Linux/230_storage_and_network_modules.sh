# Keep certain drivers for later use

# If we don't have udev then we skip this part and fall through to the old way of taking along
# all loaded modules (needed on older Linux, e.g. RHEL4)

have_udev || return 0

# Include storage drivers
STORAGE_DRIVERS=(
	$(
		find /lib/modules/$KERNEL_VERSION/kernel/drivers/{block,firewire,ide,ata,md,message,scsi,usb/storage} -type f -name '*.ko*' -printf '%f\n' 2>&1 | \
		sed -e 's/^\(.*\)\.ko.*/\1/'
		#  ^^^^- remove the .ko, faster one sed call than many basename calls or shell code
	)
)

# Include network drivers
NETWORK_DRIVERS=(
	$(
		find /lib/modules/$KERNEL_VERSION/kernel/drivers/net -type f -name '*.ko*' -printf '%f\n' 2>&1 | \
		sed -e 's/^\(.*\)\.ko.*/\1/'
		#  ^^^^- remove the .ko, faster one sed call than many basename calls or shell code
	)
)

# Include crypto drivers
CRYPTO_DRIVERS=(
	$(
		find /lib/modules/$KERNEL_VERSION/kernel/crypto -type f -name '*.ko*' -printf '%f\n' 2>&1 | \
		sed -e 's/^\(.*\)\.ko.*/\1/'
		#  ^^^^- remove the .ko, faster one sed call than many basename calls or shell code
	)
)

# Include virtualization drivers
VIRTUAL_DRIVERS=(
	$(
		find /lib/modules/$KERNEL_VERSION/kernel/drivers/{virtio,xen} -type f -name '*.ko*' -printf '%f\n' 2>&1 | \
		sed -e 's/^\(.*\)\.ko.*/\1/'
		#  ^^^^- remove the .ko, faster one sed call than many basename calls or shell code
	)
)

# Include additional drivers
EXTRA_DRIVERS=(
	$(
		find /lib/modules/$KERNEL_VERSION/{extra,weak-updates} -type f -name '*.ko*' -printf '%f\n' 2>&1 | \
		sed -e 's/^\(.*\)\.ko.*/\1/'
		#  ^^^^- remove the .ko, faster one sed call than many basename calls or shell code
	)
)
