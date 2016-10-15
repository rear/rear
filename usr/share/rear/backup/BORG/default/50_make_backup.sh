# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 20_start_backup.sh

include_list=()

# Check if backup-include.txt (created by 40_create_include_exclude_files.sh),
# really exists
if [ ! -r $TMP_DIR/backup-include.txt ]; then
    Error "Cant find include list"
fi

# Create Borg friendly include list
for i in $(cat $TMP_DIR/backup-include.txt); do
    include_list+=("$i ")
done

Log "Creating archive ${BORG_ARCHIVE_PREFIX}_$SUFFIX \
in repository $BORG_REPO on host $BORG_HOST"

# Start actual Borg backup
borg create --one-file-system --verbose --stats \
--compression $BORG_COMPRESSION --exclude-from $TMP_DIR/backup-exclude.txt \
$BORG_USERNAME@$BORG_HOST:$BORG_REPO::${BORG_ARCHIVE_PREFIX}_$SUFFIX \
${include_list[@]}

StopIfError "Failed to create backup"
