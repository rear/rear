# verify that we have a working mkisofs
#
# default for ISO_MKISOFS_BIN is to check for mkisofs and genisoimage in the path

[ -x "$ISO_MKISOFS_BIN" ]
StopIfError "Could not find 'mkisofs' compatible program. Please install 'mkisofs', 'genisoimage' or 'ebiso' into your path or manually set ISO_MKISOFS_BIN [$ISO_MKISOFS_BIN]"

# We also include 'udf' module which is required if backup archive is >= 4GiB
# and mkisofs/genisoimage is used.
if $ISO_MKISOFS_BIN --help 2>&1 >/dev/null | grep -qw -- -allow-limited-size ; then
    MODULES+=( udf )
    ISO_MKISOFS_OPTS+=" -allow-limited-size"
fi

Log "Using '$ISO_MKISOFS_BIN' to create ISO images"

# vim: set et ts=4 sw=4:
