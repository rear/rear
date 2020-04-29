# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 500_make_backup.sh

include_list=()

# Check if backup-include.txt (created by 400_create_include_exclude_files.sh),
# really exists.
if [ ! -r $TMP_DIR/backup-include.txt ]; then
    Error "Can't find include list"
fi

# Create Borg friendly include list.
for i in $(cat $TMP_DIR/backup-include.txt); do
    include_list+=("$i ")
done

# User might specify some additional output options in Borg.
# Output shown by Borg is not controlled by `rear --verbose' nor `rear --debug'
# only, if BORGBACKUP_SHOW_PROGRESS is true.
local borg_additional_options=''

is_true $BORGBACKUP_SHOW_PROGRESS && borg_additional_options+='--progress '
is_true $BORGBACKUP_SHOW_STATS && borg_additional_options+='--stats '
is_true $BORGBACKUP_SHOW_LIST && borg_additional_options+='--list --filter=AME '
is_true $BORGBACKUP_SHOW_RC && borg_additional_options+='--show-rc '
is_true $BORGBACKUP_EXCLUDE_CACHES && borg_additional_options+='--exclude-caches '
is_true $BORGBACKUP_EXCLUDE_IF_NOBACKUP && borg_additional_options+='--exclude-if-present .nobackup '
[[ -n $BORGBACKUP_TIMESTAMP ]] && borg_additional_options+="--timestamp $BORGBACKUP_TIMESTAMP "

# Borg writes all log output to stderr by default.
# See https://borgbackup.readthedocs.io/en/stable/usage/general.html#logging
#
# If we want to have log output from Borg appearing in rear logs, we don't have
# to do anything, since Borg logs to stderr and that is what rear is saving in
# Logfile.
#
# If `--progress` is used for `borg create` we don't want the output in rear
# log file, since it contains control sequences. If not used, we want Borg
# output in rear log file, the amount of logs written by Borg is determined by
# other options above e.g. by `--stats` or `--list --filter=AME`.

# Start actual Borg backup.
if is_true $BORGBACKUP_SHOW_PROGRESS; then
  borg_create 0<&6 1>&7 2>&8
else
  borg_create
fi

StopIfError "Borg failed to create backup archive, borg rc $?!"
