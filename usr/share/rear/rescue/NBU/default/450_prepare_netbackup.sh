# 450_prepare_netbackup.sh

# Bundle whichever NetBackup client startup mechanism exists on this
# system into the rescue image: the PBX (vxpbx_exchanged) and
# NetBackup client systemd units or SysV /etc/init.d scripts, or the
# legacy pre-PBX xinetd config. Copy whichever exists rather than
# deciding by NetBackup version, since that depends on OS and
# NetBackup version together.

local f=""
for f in /etc/systemd/system/vxpbx_exchanged.service /usr/lib/systemd/system/vxpbx_exchanged.service; do
    test -r "$f" && COPY_AS_IS+=( "$f" )
done
test -r "/etc/init.d/vxpbx_exchanged" && COPY_AS_IS+=( /etc/init.d/vxpbx_exchanged )

for f in /etc/systemd/system/netbackup.service /usr/lib/systemd/system/netbackup.service; do
    test -r "$f" && COPY_AS_IS+=( "$f" )
done
test -r "/etc/init.d/netbackup" && COPY_AS_IS+=( /etc/init.d/netbackup )

if [[ -r /etc/xinetd.d/vnetd || -r /etc/xinetd.d/bpcd || -r /etc/xinetd.d/vopied ]] ; then
    PROGS+=( xinetd )
    COPY_AS_IS+=( /etc/xinetd.conf /etc/xinetd.d/bpcd /etc/xinetd.d/vnetd /etc/xinetd.d/vopied )
fi
