#
# prepare stuff for VEEAM
#

COPY_AS_IS+=("${COPY_AS_IS_VEEAM[@]}")
REQUIRED_PROGS+=("${REQUIRED_PROGS_VEEAM[@]}")
# enable default ramdisk if not set to satisfy Veeam 12.1ff requirements 
is_true "$USE_RAMDISK" || USE_RAMDISK=yes
