# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 20_start_backup.sh

include_list=()

# Check if backup-include.txt (created by 40_create_include_exclude_files.sh),
# really exists.
if [ ! -r $TMP_DIR/backup-include.txt ]; then
    Error "Can't find include list"
fi

# Create Borg friendly include list.
for i in $(cat $TMP_DIR/backup-include.txt); do
    include_list+=("$i ")
done

# Prepare option for Borg compression.
# If user did not set anything in BORGBACKUP_COMPRESSION,
# Borg default compression will be used.
opt_compression=""
if [ ! -z $BORGBACKUP_COMPRESSION ]; then
    opt_compression="--compression $BORGBACKUP_COMPRESSION"
fi

Log "Creating archive ${BORGBACKUP_ARCHIVE_PREFIX}_$SUFFIX \
in repository $BORGBACKUP_REPO on host $BORGBACKUP_HOST"

# Start actual Borg backup.
borg create --one-file-system --verbose --stats $opt_compression \
--exclude-from $TMP_DIR/backup-exclude.txt \
$BORGBACKUP_USERNAME@$BORGBACKUP_HOST:$BORGBACKUP_REPO::\
${BORGBACKUP_ARCHIVE_PREFIX}_$SUFFIX \
${include_list[@]}

StopIfError "Failed to create backup"
