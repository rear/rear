# verify that we have a working mkisofs
#
# default for ISO_MKISOFS_BIN is to check for mkisofs and genisoimage in the path

[ -x "$ISO_MKISOFS_BIN" ]
StopIfError "Could not find 'mkisofs' compatible program. Please install 'mkisofs', 'genisoimage' or 'ebiso' into your path or manually set ISO_MKISOFS_BIN [$ISO_MKISOFS_BIN]"

Log "Using '$ISO_MKISOFS_BIN' to create ISO images"
