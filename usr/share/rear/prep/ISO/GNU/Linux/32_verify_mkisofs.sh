# verify that we have a working mkisofs
#
# default for ISO_MKISOFS_BIN is to check for mkisofs and genisoimage in the path

test -x "$ISO_MKISOFS_BIN"
ProgressStopIfError $? "Could not find 'mkisofs' compatible program. Please install 'mkisofs' or 'genisoimage' into your path or manually set ISO_MKISOFS_BIN [$ISO_MKISOFS_BIN]"
Log "Using '$ISO_MKISOFS_BIN' to create ISO images"
