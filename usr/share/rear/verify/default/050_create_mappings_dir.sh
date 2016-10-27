# 050_create_mappings_dir.sh
# We need the /etc/rear/mappings directory before the finalize script 30_create_mac_mappings.sh
# script is invoked. If the directory was not created then the /etc/rear/mappings/mac file
# cannot created as described in issue #861
# We were able to reproduce the behavior described in #861

[[ ! -d "$CONFIG_DIR/mappings" ]] && mkdir -m 755 "$CONFIG_DIR/mappings"
