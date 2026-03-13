# Check for deprecated ISO configuration variables

test "$ISO_DEFAULT" && Error "ISO_DEFAULT is no longer supported. Use ISO_RECOVER_MODE instead."
