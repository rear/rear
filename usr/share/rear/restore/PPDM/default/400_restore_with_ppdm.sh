# restore with PPDM

for asset in "${!PPDM_ASSETS_AND_SSIDS[@]}"; do
    ssid=${PPDM_ASSETS_AND_SSIDS[$asset]}
    LogPrint "Starting restore of $asset"

    ddfsrc -r "/mnt/local/$asset" -S $ssid -i y \
        -h DFA_SI_DD_HOST=$PPDM_DD_IP \
        -h DFA_SI_DD_USER=$PPDM_DD_USERNAME \
        -h DFA_SI_DEVICE_PATH=$PPDM_STORAGE_UNIT 1>&7 2>&8 ||
        Error "Failed to restore $asset"
    unset ssid
    LogPrint "Finished restoring $asset"
done
