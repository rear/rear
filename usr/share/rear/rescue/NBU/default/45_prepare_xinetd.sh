# 45_prepare_xinetd.sh
# prepare environment for xinetd for NBU services
# NBU only supports RHEL/SLES distributions and both use xinetd daemon

PROGS=( "${PROGS[@]}" xinetd )
COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/xinetd.conf /etc/xinetd.d/bpcd /etc/xinetd.d/vnetd /etc/xinetd.d/vopied )
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
chmod $v +x $ROOTFS_DIR/etc/scripts/system-setup.d/90-xinetd.sh >&2
