
# Verify that we have a working program to make ISO9660 filesystem.
#
# In default.conf ISO_MKISOFS_BIN is to check what there is in the path with
# xorrisofs used as the preferred method for generating the iso image
# and mkisofs and genisoimage as second and third option
# but for UEFI bootable systems 'ISO_MKISOFS_BIN=/usr/bin/ebiso' is used.
test -x "$ISO_MKISOFS_BIN" || Error "Could not find program to make ISO9660 filesystem. Install 'mkisofs', 'genisoimage' or 'ebiso' or specify ISO_MKISOFS_BIN (currently $ISO_MKISOFS_BIN)"

# Include 'udf' module which is required if backup archive is >= 4GiB and mkisofs/genisoimage is used:
IsInArray "all_modules" "${MODULES[@]}" || MODULES+=( udf )
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
# "man mkisofs" on openSUSE Leap 15.1 for /usr/bin/mkisofs from the mkisofs RPM
# does not mention 'allow-limited-size' neither does 'mkisofs --help' show it
# but it reads (excerpt):
#   If you like to have files larger than 2 GB, you need to specify -iso-level 3 or above.
# The 'output/ISO/...create_iso_image.sh' scripts
#   output/ISO/Linux-i386/810_prepare_multiple_iso.sh
#   output/ISO/Linux-i386/820_create_iso_image.sh
#   output/ISO/Linux-i386/830_create_iso_image_EFISTUB.sh
#   output/ISO/Linux-ppc64le/820_create_iso_image.sh
# specify '-iso-level 3' only
#   output/ISO/Linux-ia64/800_create_isofs.sh
# does not specify '-iso-level 3'
# so on IA-64 (Intel Itanium architecture) there is probably a 2GiB file size limit.
# Also 'ebiso --help' does not mention 'allow-limited-size'.
if $ISO_MKISOFS_BIN --help 2>&1 >/dev/null | grep -qw -- -allow-limited-size ; then
    ISO_MKISOFS_OPTS+=" -allow-limited-size"
fi

# ebiso has a 2GiB file size limit
# cf. https://github.com/gozora/ebiso/issues/12
# so ISO_FILE_SIZE_LIMIT must not be greater than 2GiB
if test "ebiso" = "$( basename $ISO_MKISOFS_BIN )" ; then
    # 2 GiB =  2 * 1024 * 1024 * 1024 bytes = 2147483648 bytes:
    test $ISO_FILE_SIZE_LIMIT -le 2147483648 || Error "ebiso has a 2GiB file size limit but ISO_FILE_SIZE_LIMIT is greater than 2GiB"
fi

DebugPrint "Using '$ISO_MKISOFS_BIN' to create ISO filesystem images"

# vim: set et ts=4 sw=4:
