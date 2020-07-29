#
# 200_prompt_user_to_start_restore.sh
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# The user has to do the actual backup restore manually in this case here.
#

test "$BACKUP_PROG" = "duply" || return 0

# DUPLY_RESTORE_OK="y" is set when restore/DUPLICITY/default/150_restore_duply.sh succeeded:
test "$DUPLY_RESTORE_OK" = "y" && return

# If restore should be done with duply, but it failed, give the user a chance to fix it manually:

LogPrint "Restore your backup in the provided shell to $TARGET_FS_ROOT
When finished, type exit in the shell to continue recovery.
You can use duplicity / duply to restore your backup."

# Save TMPDIR only if one is already set:
test $TMPDIR && old_TMPDIR=$TMPDIR
export TMPDIR=$TARGET_FS_ROOT
rear_shell "Did you restore the backup to $TARGET_FS_ROOT ? Are you ready to continue recovery ?"
# Restore TMPDIR if it was saved above (i.e. when TMPDIR had been set before)
# otherwise unset a possibly set TMPDIR (i.e. when TMPDIR had not been set before):
test $old_TMPDIR && TMPDIR=$old_TMPDIR || unset TMPDIR
