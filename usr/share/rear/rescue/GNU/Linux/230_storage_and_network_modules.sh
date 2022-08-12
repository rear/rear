
# Determine some usually needed kernel drivers (kernel modules)
# cf. the subsequent rescue/GNU/Linux/240_kernel_modules.sh script.

# Local functions that are 'unset' at the end of this script:
function find_modules_in_dirs () {
    # The '2>/dev/null' drops find error messages mainly for non-existent module directories
    # cf. https://github.com/rear/rear/pull/1359#issuecomment-300800995
    # and the
    #    ... | sed -e 's/^\(.*\)\.ko.*/\1/'
    # removes the trailing .ko faster via one sed call than many basename calls or shell code:
    find "$@" -type f -name '*.ko*' -printf '%f\n' 2>/dev/null | sed -e 's/^\(.*\)\.ko.*/\1/'
}

# Include storage drivers
Log "Including storage drivers"
STORAGE_DRIVERS=( $( find_modules_in_dirs /lib/modules/$KERNEL_VERSION/kernel/drivers/{block,firewire,ide,ata,md,message,scsi,usb/storage,s390/block,s390/scsi} ) )

# Include network drivers
Log "Including network drivers"
NETWORK_DRIVERS=( $( find_modules_in_dirs /lib/modules/$KERNEL_VERSION/kernel/drivers/{net,s390/net} ) )

# Include crypto drivers
Log "Including crypto drivers"
CRYPTO_DRIVERS=( $( find_modules_in_dirs /lib/modules/$KERNEL_VERSION/kernel/{crypto,s390/crypto} ) )

# Include virtualization drivers
Log "Including virtualization drivers"
VIRTUAL_DRIVERS=( $( find_modules_in_dirs /lib/modules/$KERNEL_VERSION/kernel/drivers/{virtio,xen} ) )

# Include additional drivers
Log "Including additional drivers"
EXTRA_DRIVERS=( $( find_modules_in_dirs /lib/modules/$KERNEL_VERSION/{extra,weak-updates} ) )

# Local functions must be 'unset' because bash does not support 'local function ...'
# cf. https://unix.stackexchange.com/questions/104755/how-can-i-create-a-local-function-in-my-bashrc
unset -f find_modules_in_dirs

