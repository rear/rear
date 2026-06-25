# 250_add_extra_excludes_for_rsync.sh

# Seems we do not need extra excludes with RSYNC workflow besides we already have defined in ReaR (#3601)
# BACKUP_PROG_EXCLUDE+=( '/proc/*' '/run/*' '/sys/*' '/dev/pts/*' '/var/tmp/*' '/mnt/*' '/media/*' )

# script 400_create_include_exclude_files.sh will include above mentioned values in the $TMP_DIR/backup-excludes.txt file
