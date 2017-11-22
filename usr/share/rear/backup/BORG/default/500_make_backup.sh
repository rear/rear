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

Log "Creating archive ${BORGBACKUP_ARCHIVE_PREFIX}_$BORGBACKUP_SUFFIX \
in repository $BORGBACKUP_REPO on host $BORGBACKUP_HOST"

# Only in ReaR verbose mode also show borg progress output and stats
local borg_progress=''
test "$verbose" && borg_progress='--progress --stats'

# Start actual Borg backup.
borg create --one-file-system $borg_progress $verbose \
$BORGBACKUP_OPT_COMPRESSION $BORGBACKUP_OPT_REMOTE_PATH \
--exclude-from $TMP_DIR/backup-exclude.txt \
$BORGBACKUP_USERNAME@$BORGBACKUP_HOST:$BORGBACKUP_REPO::\
${BORGBACKUP_ARCHIVE_PREFIX}_$BORGBACKUP_SUFFIX \
${include_list[@]} 0<&6 1>&7 2>&8

StopIfError "Failed to create backup"
