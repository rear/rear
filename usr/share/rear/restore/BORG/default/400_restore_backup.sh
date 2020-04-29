# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 400_restore_backup.sk

# Borg restores to cwd.
# Switch current working directory or die.
pushd $TARGET_FS_ROOT >/dev/null
StopIfError "Could not change directory to $TARGET_FS_ROOT!"

# User might specify some additional output options in Borg.
# Output shown by Borg is not controlled by `rear --verbose' nor `rear --debug'
# only, if BORGBACKUP_SHOW_PROGRESS is true.
local borg_additional_options=''

is_true $BORGBACKUP_SHOW_PROGRESS && borg_additional_options+='--progress '
is_true $BORGBACKUP_SHOW_LIST && borg_additional_options+='--list '
is_true $BORGBACKUP_SHOW_RC && borg_additional_options+='--show-rc '

# Start actual restore.
if is_true $BORGBACKUP_SHOW_PROGRESS; then
    borg_extract 0<&6 1>&7 2>&8
elif is_true $VERBOSE; then
    borg_extract 0<&6 1>&7 2> >(tee >(cat 1>&2) >&8)
else
    borg_extract 0<&6 1>&7
fi

LogPrintIfError "Borg reported error during restore, borg rc $?!"
LogPrint 'Borg OS restore finished successfully.'
popd >/dev/null
