cat - <<EOF >> "$ROOTFS_DIR/etc/rear/rescue.conf"
# TMPDIR variable may be defined in local.conf file as prefix dir for mktemp command
# e.g. by defining TMPDIR=/var we would get our BUILD_DIR=/var/tmp/rear.XXXXXXXXXXXX
# However, in rescue we want our BUILD_DIR=/tmp/rear.XXXXXXX as we are not sure that
# the user defined TMPDIR would exist in our rescue image
# by 'unset TMPDIR' we achieve above goal (as rescue.conf is read after local.conf)!
unset TMPDIR
EOF
