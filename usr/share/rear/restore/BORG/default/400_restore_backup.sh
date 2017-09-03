# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 400_restore_backup.sk

# Borg restores to cwd.
# Switch current working directory or die.
cd $TARGET_FS_ROOT
StopIfError "Could not change directory to /mnt/local"

# Start actual restore.
# Scope of LC_ALL is only within run of `borg extract'.
# This avoids Borg problems with restoring UTF-8 encoded files names in archive
# and should not interfere with remaining stages of rear recover.
# This is still not the ideal solution, but best I can think of so far :-/.
LogPrint "Recovering from Borg archive $BORGBACKUP_ARCHIVE"
LC_ALL=en_US.UTF-8 \
borg extract --sparse $BORGBACKUP_OPT_REMOTE_PATH \
$BORGBACKUP_USERNAME@$BORGBACKUP_HOST:$BORGBACKUP_REPO::$BORGBACKUP_ARCHIVE
StopIfError "Could not successfully finish Borg restore"

LogPrint "Borg OS restore finished successfully"
