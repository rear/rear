# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.
#
# the user has to do the main part here :-)
#
#

if [ "$BACKUP_PROG" = "duply" ]; then

    [[ "$DUPLY_RESTORE_OK" = "y" ]] && return

    # if restore should be done with duply, but it failed, give the user
    # a chance to fix it manually

    LogPrint "Please restore your backup in the provided shell to /mnt/local and, 
    when finished, type exit in the shell to continue recovery. 
    You can use duplicity / duply to restore your backup."

    export TMPDIR=/mnt/local
    rear_shell "Did you restore the backup to /mnt/local ? Are you ready to continue recovery ?"

fi    
