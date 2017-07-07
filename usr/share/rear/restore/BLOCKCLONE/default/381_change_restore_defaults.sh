# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 381_change_restore_defaults.sh

local archive_name=${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}\
${BACKUP_PROG_COMPRESS_SUFFIX}

# Allow user to change restore destination
LogUserOutput "Restore $archive_name to device: [$BLOCKCLONE_SOURCE_DEV]"
change_default BLOCKCLONE_SOURCE_DEV
