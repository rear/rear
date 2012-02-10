# we will create a $CONFIG_DIR/mappings/mac file if needed
PATCH_FILES=( /mnt/local/etc/sysconfig/*/ifcfg-* )

# skip if no network configuration files are found
test $PATCH_FILES || return 0

[[ -f $CONFIG_DIR/mappings/mac ]] && return 0	# if a "mac" is found no need to create one

for file in "${PATCH_FILES[@]}"; do
	grep -q HWADDR $file || continue
	dev=$(echo $file | cut -d- -f3)
	old_mac=$(grep HWADDR $file | cut -d= -f2)
	new_mac=$(cat /sys/class/net/$dev/address)
	[[ -z "$new_mac" ]] && continue
	[[ "$(echo $old_mac | sed -e 'y/abcdef/ABCDEF/')" = "$(echo $new_mac | sed -e 'y/abcdef/ABCDEF/')" ]] && continue
	echo "$old_mac $new_mac $dev" >> $CONFIG_DIR/mappings/mac
done
