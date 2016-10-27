# 460_save_nsr_server_name.sh
if [[ ! -z "$NSRSERVER" ]]; then
    : # do nothing
elif [[ -f $NSR_ROOT_DIR/res/servers ]]; then
    NSRSERVER=$( cat $NSR_ROOT_DIR/res/servers | head -1 )
elif [[ -d $NSR_ROOT_DIR/res/nsrladb/03 ]]; then
    NSRSERVER=$(grep servers $NSR_ROOT_DIR/res/nsrladb/*/* | tail -1 | awk '{print $2}' | sed -e 's/[;,]//' )
fi

if [[ -z "$NSRSERVER" ]]; then
    Log "The EMC NetWorker server name could not be found automatically."
    Error "Please define manually the EMC NetWorker server name under $NSR_ROOT_DIR/res/servers"
fi

echo "$NSRSERVER" > $VAR_DIR/recovery/nsr_server
