# build/GNU/Linux/640_verify_lvm_conf.sh
# Purpose is to turn off the
# "WARNING: Failed to connect to lvmetad. Falling back to device scanning"
# in the output during the 'rear recover' process - see issue
# https://github.com/rear/rear/issues/2044 for more details

# Nothing to do when there is no $ROOTFS_DIR/etc/lvm/lvm.conf file:
test -f $ROOTFS_DIR/etc/lvm/lvm.conf || return 0

# Determine whether or not lvmetad is in use:
local use_lvmetad_active=""

# First try the older traditional 'lvm dumpconfig':
lvm dumpconfig | grep -q 'use_lvmetad=1' && use_lvmetad_active="yes"

# If 'lvm dumpconfig' did not work use the newer 'lvmconfig':
if ! test "$use_lvmetad_active" ; then
    lvmconfig | grep -q 'use_lvmetad=1' && use_lvmetad_active="yes"
fi

# As fallback try 'lvm version':
if ! test "$use_lvmetad_active" ; then
    lvm version | grep -q -- '--enable-lvmetad' && use_lvmetad_active="yes"
fi

# Skip enforcing 'use_lvmetad = 0' in $ROOTFS_DIR/etc/lvm/lvm.conf
# if lvmetad is not in use:
is_true "$use_lvmetad_active" || return 0

# Enforce 'use_lvmetad = 0' in $ROOTFS_DIR/etc/lvm/lvm.conf
sed -i -e 's/.*use_lvmetad =.*/# &/' -e '/global {/ a use_lvmetad = 0' $ROOTFS_DIR/etc/lvm/lvm.conf
