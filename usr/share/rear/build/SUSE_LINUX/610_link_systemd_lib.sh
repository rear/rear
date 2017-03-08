# Fedora puts systemd stuff into /usr/lib/systemd and SUSE under /lib/systemd
pushd $ROOTFS_DIR >/dev/null
	if [[ -d usr/lib/systemd/system ]];  then
		if [[ ! -d lib/systemd/system ]]; then
			ln -sf $v ../../usr/lib/systemd/system $ROOTFS_DIR/lib/systemd/system >&2
		fi
	else
		Error "Missing usr/lib/systemd/system - too confused to continue"
	fi
popd >/dev/null

