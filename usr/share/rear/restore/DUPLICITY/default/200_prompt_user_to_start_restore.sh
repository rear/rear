# 200_prompt_user_to_start_restore.sh
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# the user has to do the main part here :-)
#
#

if [ "$BACKUP_PROG" = "duply" ]; then

    [[ "$DUPLY_RESTORE_OK" = "y" ]] && return

    # if restore should be done with duply, but it failed, give the user
    # a chance to fix it manually

    LogPrint "Please restore your backup in the provided shell to $TARGET_FS_ROOT and,
    when finished, type exit in the shell to continue recovery.
    You can use duplicity / duply to restore your backup."

    export TMPDIR=$TARGET_FS_ROOT
    rear_shell "Did you restore the backup to $TARGET_FS_ROOT ? Are you ready to continue recovery ?"

fi
