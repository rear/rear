# verify that we have a working mkisofs
#
# default for ISO_MKISOFS_BIN is to check for mkisofs and genisoimage in the path

[ -x "$ISO_MKISOFS_BIN" ]
StopIfError "Could not find 'mkisofs' compatible program. Please install 'mkisofs', 'genisoimage' or 'ebiso' into your path or manually set ISO_MKISOFS_BIN [$ISO_MKISOFS_BIN]"

# We also include 'udf' module which is required if backup archive is >= 4GiB and mkisofs/genisoimage is used.
# "man mkisofs" (at least on SLES12-SP5 for /usr/bin/mkisofs from the cdrkit-cdrtools-compat RPM) reads (excerpts):
#   -allow-limited-size
#     When processing files larger than 2GiB which cannot be represented in ISO9660 level 1 or 2,
#     add them with a shrunk visible file size to ISO9660 and with the correct visible file size to the UDF system.
#     The result is an inconsistent filesystem and users need to make sure that they really use UDF
#     rather than ISO9660 driver to read a such disk. Implies enabling -udf. See also -iso-level 3
#   -udf
#     Include UDF filesystem support in the generated filesystem image.
#     UDF support is currently in alpha status and for this reason,
#     it is not possible to create UDF-only images.
#     UDF data structures are currently coupled to the Joliet structures,
#     so there are many pitfalls with the current implementation.
#     There is no UID/GID support, there is no POSIX permission support, there is no support for  symlinks.
#   -iso-level level
#      With level 1, files may only consist of one section and filenames are restricted to 8.3 characters.
#      With level 2, files may only consist of one section.
#      With level 3, no restrictions (other than ISO-9660:1988) do apply.
#      Starting with this level, genisoimage also allows files to be larger than 4 GB
#      by implementing ISO-9660 multi-extent files.
#      With all ISO9660 levels from 1 to 3, all filenames are restricted to uppercase letters,
#      numbers and underscores (_). Filenames are limited to 31 characters,
#      directory nesting is limited to 8 levels, and pathnames are limited to 255 characters.
if $ISO_MKISOFS_BIN --help 2>&1 >/dev/null | grep -qw -- -allow-limited-size ; then
    MODULES+=( udf )
    ISO_MKISOFS_OPTS+=" -allow-limited-size"
fi

Log "Using '$ISO_MKISOFS_BIN' to create ISO images"

# vim: set et ts=4 sw=4:
