
# Verify that at the end of the 'prep' stage
# the ReaR recovery system area (i.e. ROOTFS_DIR)
# is still empty, see prep/README
#
# Only those workflows that actually make a ReaR recovery system via
#   SourceStage "rescue"
#   SourceStage "build"
#   SourceStage "pack"
#   SourceStage "output"
# (currently those workflows are mkrescue, mkbackup and mkopalpba)
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

test "$( ls -A $ROOTFS_DIR )" || return 0
LogPrintError "Modified ReaR recovery system area after 'prep' stage ($ROOTFS_DIR not empty)"
DebugPrint "$( find $ROOTFS_DIR )"
return 1
