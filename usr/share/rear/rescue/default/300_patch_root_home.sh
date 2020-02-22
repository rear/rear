# Update root home directory

# When home directory or root user is moved away from default "/root"
# we will move it in ReaR recovery system as well. This will help to keep
# recovery system similar to original as much as possible.
# When root home directory is in default "/root" action in this file will be
# skipped.
test $ROOT_HOME_DIR = "/root" && return

sed -i s#export\ HOME=/root\$#export\ HOME=${ROOT_HOME_DIR}#g $ROOTFS_DIR/bin/login
sed -i s#root::0:0:root:/root:#root::0:0:root:${ROOT_HOME_DIR}:#g $ROOTFS_DIR/etc/passwd
