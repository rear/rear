# Because user might mis-configure EFI_STUB by values like '" ", "", "foobar" ...'
# We will check such mis-configuration and bailout with error.

# If both is_false $EFI_STUB and is_true $EFI_STUB return false, there is
# something wrong with configuration ...
is_false $EFI_STUB || is_true $EFI_STUB || Error "EFI_STUB=\"$EFI_STUB\" is incorrect option value pair."
