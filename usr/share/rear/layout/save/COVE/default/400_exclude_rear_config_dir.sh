# 400_exclude_rear_config_dir.sh
#
# Exclude ReaR config directory from CHECK_CONFIG_FILES array since this is not
# recovered by the Backup Manager.

CHECK_CONFIG_FILES=( $( RmInArray "$CONFIG_DIR" "${CHECK_CONFIG_FILES[@]}" ) )
