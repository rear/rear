# 450_request_client_source.sh

# Ask which NetBackup client backup to restore from. Defaults to the
# current CLIENT_NAME. The operator can enter a different source
# client name for a cross restore, but the source must be authorized
# as an altname of the destination on the Primary server, or
# 'bprestore' will fail.

# Default: no implicit cross restore. Only an explicit answer below changes this.
NBU_CLIENT_SOURCE="$NBU_CLIENT_NAME"
test -n "$NBU_CLIENT_SOURCE" || Error "NBU_CLIENT_NAME is not set. Cannot determine a NetBackup source client to restore from. This likely means CLIENT_NAME was removed from bp.conf during the 250_check_nbu_client_name.sh pause."

LogPrint ""
if is_true "$NBU_CLIENT_RENAMED" ; then
    LogPrint "This client's hostname was changed from $NBU_CLIENT_ORIGINAL to $NBU_CLIENT_NAME prior to this restore."
fi
LogPrint "NetBackup source client for this restore: $NBU_CLIENT_SOURCE."
while true ; do
    read -t $WAIT_SECS -r -p "Enter source client name to restore from or press ENTER [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8
    # ENTER or timeout keeps the default
    test -z "$REPLY" && break
    if [[ "$REPLY" =~ ^[A-Za-z0-9._-]+$ ]] ; then
        NBU_CLIENT_SOURCE="$REPLY"
        LogPrint ""
        LogPrint "Restoring from a DIFFERENT NetBackup client: $NBU_CLIENT_SOURCE (instead of $NBU_CLIENT_NAME)."
        LogPrint "Warning: 'bprestore' needs the source client authorized as an altname"
        LogPrint "of the destination on the Primary server, or it will fail."
        break
    fi
    LogPrintError "Invalid client name '$REPLY'. Use only letters, digits, '.', '_' and '-'."
done
