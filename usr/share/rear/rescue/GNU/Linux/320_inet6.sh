# 320_inet6.sh

if [[ -f /proc/net/if_inet6 ]]; then
    cat $v /proc/net/if_inet6 > "$VAR_DIR/recovery/if_inet6" >&2
fi
