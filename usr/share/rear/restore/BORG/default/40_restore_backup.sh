# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 20_start_restore.sh

# Borg restores to cwd
# Switch current working directory or die
cd $TARGET_FS_ROOT
StopIfError "Could not change directory to /mnt/local"

# Start actual restore
# Scope of LC_ALL is only within run of `borg extract'.
# This avoids Borg problems with restoring UTF-8 encoded files names in archive
# and should not interfere with remaining stages of rear recover.
# This is still not the ideal sollution, but best I can think of so far :-/
LogPrint "Recovering from Borg archive $ARCHIVE"
LC_ALL=rear.UTF-8 \
borg extract --sparse $BORG_USERNAME@$BORG_HOST:$BORG_REPO::$ARCHIVE
StopIfError "Could not successfully finish Borg restore"

LogPrint "Borg OS restore finished successfully"
