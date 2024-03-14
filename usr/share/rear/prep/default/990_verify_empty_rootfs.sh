
# Verify at the end of the 'prep' stage
# that the ReaR recovery system area (i.e. ROOTFS_DIR)
# is still empty, see prep/README
#
# Only those workflows that actually make a ReaR recovery system
# by running the stages 'rescue', 'build', 'pack', and 'output'
# (in particular the workflows mkrescue, mkbackup and mkopalpba)
# should modify something in ROOTFS_DIR.
#
# In contrast when other workflows that run the 'prep' stage (e.g. mkbackuponly)
# modify something in ROOTFS_DIR then all those modifications will be lost
# because no ReaR recovery system with those modifications is made.
# So the problem is possible inconsistencies between what gets actually used
# during "rear recover" (i.e. the last actually made ReaR recovery system)
# versus what other workflows that run the 'prep' stage may need to have.
# For example mkbackuponly may need a modified ReaR recovery system
# when backup config variables need updated values in the recovery system
# e.g. an updated value for BACKUP_PROG_EXCLUDE or something similar.

# For now do not error out because currently
# some 'prep' scripts modify things in ROOTFS_DIR,
# see https://github.com/rear/rear/issues/2951

# Only check for regular files in ROOTFS_DIR
# so in particular empty directories like ROOTFS_DIR/TMP_DIR are OK
# cf. https://github.com/rear/rear/commit/9b4efb2469b8cf3585206dbb10700960b480008e#r139765325
test "$( find $ROOTFS_DIR -type f )" || return 0
DebugPrint "Modified ReaR recovery system area after 'prep' stage ($ROOTFS_DIR contains regular files)"
Debug "$( find $ROOTFS_DIR -ls )"
return 1
