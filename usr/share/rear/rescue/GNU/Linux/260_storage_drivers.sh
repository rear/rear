# collect info about storage drivers

have_udev || return 0
FindStorageDrivers >$VAR_DIR/recovery/storage_drivers
