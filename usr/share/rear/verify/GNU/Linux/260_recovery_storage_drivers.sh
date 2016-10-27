# find the storage drivers for the recovery hardware

have_udev || return 0
# the difference is that we refer to the stuff in TMP_DIR which was created
# during the recover stages
FindStorageDrivers $TMP_DIR/dev >$TMP_DIR/storage_drivers

# compare
if ! diff -u $VAR_DIR/recovery/storage_drivers $TMP_DIR/storage_drivers >&2 ; then
	# TODO this branch is obsolete as this script runs only under UDEV
	if have_udev ; then
		LogPrint "NOTICE: Will do driver migration"
	else
		LogPrint "WARNING:
Some or all of the storage drivers are different between this system and
the source system. Please make sure to adjust the recovered system before
attempting to boot it.

BTW, with newer Kernel 2.6 systems this would happen automatically.
"
	fi
fi
