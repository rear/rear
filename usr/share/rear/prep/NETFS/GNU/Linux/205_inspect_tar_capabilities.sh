# prep/NETFS/GNU/Linux/205_inspect_tar_capabilities.sh
# The purpose is to inspect the 'tar --usage' for certain capabilities and if found
# add these to the BACKUP_PROG_OPTIONS array
# See also issue https://github.com/rear/rear/issues/1175

# As we will only inspect 'tar' we will return if BACKUP_PROG=rsync
[[ "$(basename $BACKUP_PROG)" != "tar" ]] && return

# BACKUP_PROG=tar - continue:
# Verify extended attributes being present:
if tar --usage | grep -q -- --xattrs ; then
    BACKUP_PROG_OPTIONS+=( "--xattrs" )
    PROGS+=( getfattr setfattr )
fi

# Verify extended capabilities are present (incl. SElinux security capabilities)
# For example : getcap /bin/ping
#  /bin/ping = cap_net_admin,cap_net_raw+p
# After recovery we should see the same capabilities

if tar --usage | grep -q -- --xattrs-include ; then
    BACKUP_PROG_OPTIONS+=( "--xattrs-include=security.capability" "--xattrs-include=security.selinux" )
    # prep/GNU/Linux/310_include_cap_utils.sh uses NETFS_RESTORE_CAPABILITIES=( 'Yes' ) to kick in next line, and is
    # meant to save capabilities via rescue/NETFS/default/610_save_capabilities.sh
    # Here we try to achieve the same via the 'tar' program
    PROGS+=( getcap setcap )
fi
if tar --usage | grep -q -- --acls ; then
   BACKUP_PROG_OPTIONS+=( "--acls" )
   PROGS+=( getfacl setfacl )
fi

# --selinux option was covered by script 200_selinux_in_use.sh

# save the BACKUP_PROG_OPTIONS array content to the $ROOTFS_DIR/etc/rear/rescue.conf
# we need that for the restore part with tar
echo "BACKUP_PROG_OPTIONS=( ${BACKUP_PROG_OPTIONS[@]} )" >> $ROOTFS_DIR/etc/rear/rescue.conf
