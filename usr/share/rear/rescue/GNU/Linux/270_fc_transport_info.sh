# collect output from production SAN disks

find /sys/class/fc_transport -follow -maxdepth 6 \( -name model -o -name vendor -o -name rev -name state -o -name model_name -o -name size -o -name node_name \) 2>/dev/null| egrep -v 'driver|rport|power|drivers|devices' | xargs grep '.' > $VAR_DIR/recovery/fc_transport.info  >&2

if [[ -s $VAR_DIR/recovery/fc_transport.info ]]; then
    Log "Collected the SAN disks info into $VAR_DIR/recovery/fc_transport.info"
    # here we could some additional stuff or add executables or such
else
    rm -f $VAR_DIR/recovery/fc_transport.info  # if file is empty just removed it
fi
