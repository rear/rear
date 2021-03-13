# 450_prepare_xinetd.sh
# prepare environment for xinetd for NBU services (only if NBU version <7.x)
# NBU only supports RHEL/SLES distributions and both use xinetd daemon

[ -f /usr/openv/netbackup/bin/version ] && \
	NBU_version=$(grep -i netbackup /usr/openv/netbackup/bin/version | awk '{print $2}' | cut -d'.' -f1) || \
	NBU_version=0

[[ $NBU_version -ge 7 ]] && return	# NBU is not using xinetd when version >=7.x

PROGS+=( xinetd )
COPY_AS_IS+=( /etc/xinetd.conf /etc/xinetd.d/bpcd /etc/xinetd.d/vnetd /etc/xinetd.d/vopied )
cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-xinetd.sh <<-EOF
echo "Starting a minimal xinetd daemon ..."
xinetd
if [ ! -f /etc/xinetd.d/vnetd ]; then
        /usr/openv/netbackup/bin/vnetd -standalone
fi
if [ ! -f /etc/xinetd.d/bpcd ]; then
        /usr/openv/netbackup/bin/bpcd -standalone
fi
EOF
chmod $v +x $ROOTFS_DIR/etc/scripts/system-setup.d/90-xinetd.sh
