# prepare some checks
# we want to tell the user if we didn't install a boot loader. To accomplish this we set a variable
# that is unset by all boot-loader installation scripts
NOBOOTLOADER=1

# read the BOOTLOADER if it was defined
if [[ -f $VAR_DIR/recovery/bootloader ]]; then
    BOOTLOADER=$( cat $VAR_DIR/recovery/bootloader )
fi
