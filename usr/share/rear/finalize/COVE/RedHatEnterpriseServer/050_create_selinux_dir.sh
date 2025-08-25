#
# Create /selinux directory on RHEL and CentOS 6
#

if [ "${OS_VERSION%%.*}" = "6" ] ; then
    mkdir -p "$TARGET_FS_ROOT/selinux" || true
fi
