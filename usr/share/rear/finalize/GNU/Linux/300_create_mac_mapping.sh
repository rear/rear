
# we will create a $CONFIG_DIR/mappings/mac file if needed

# because the bash option nullglob is set in rear (see usr/sbin/rear)
# PATCH_FILES is empty if nothing matches $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-*
PATCH_FILES=( $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-* )

# skip if no network configuration files are found
test $PATCH_FILES || return 0

# if a "mac" is found no need to create one
[[ -f $CONFIG_DIR/mappings/mac ]] && return 0

for file in "${PATCH_FILES[@]}"; do
	grep -q HWADDR $file || continue
	dev=$(echo $file | cut -d- -f3)
	old_mac=$(grep HWADDR $file | cut -d= -f2)
	new_mac=$(cat /sys/class/net/$dev/address)
	[[ -z "$new_mac" ]] && continue
	[[ "$(echo $old_mac | sed -e 'y/abcdef/ABCDEF/')" = "$(echo $new_mac | sed -e 'y/abcdef/ABCDEF/')" ]] && continue
	echo "$old_mac $new_mac $dev" >> $CONFIG_DIR/mappings/mac
done
