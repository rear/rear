# check for valid lockbox

# ddfsadmin lockbox -query

# success return code 0 and this output
# DD_IP           Storage Unit                                                     DD_USERNAME          DD_Config_Type
# 192.168.1.30    Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  Linux-ppdm-01-f3392  PROTECTION

# failure return code also 0 and this or other output
# 2024-01-16T15:30:51.103Z Error retrieving password from lockbox

function ppdm_get_config_from_lockbox {
    # Note: We replace Storage Unit with Storage_Unit so that our read call below can successfully split on space characters :-)
    local res _h1 _h2 _h3 _h4
    res=$(
        ddfsadmin lockbox -query 2>&1 | \
        sed -e 's/Storage Unit/Storage_Unit/g'
        ) || \
            Error "Could not query lockbox:$LF$res"

    if [[ "$res" != *DD_IP* ]]; then
        Log "Querying lockbox failed with$LF$res"
        return 1
    fi
    Log "lockbox result:$LF$res"

    read -d '' _h1 _h2 _h3 _h4 PPDM_DD_IP PPDM_STORAGE_UNIT PPDM_DD_USERNAME PPDM_DD_CONFIG_TYPE <<<"$res"
    [[ "$_h1" == DD_IP && "$_h2" == Storage_Unit && $_h3 == DD_USERNAME && $_h4 == DD_Config_Type ]] ||
        BugError "Headings of ddfsadmin lockbox -query differ from what we expect: $_h1 $_h2 $_h3 $_h4"
}

local start_wait_for_lockbox=$SECONDS waiting=0 found=0
while [[ "$PPDM_DD_IP" == "" ||
        "$PPDM_STORAGE_UNIT" == "" ||
        "$PPDM_DD_USERNAME" == "" ||
        "$PPDM_DD_CONFIG_TYPE" == "" 
        ]]
    do
    ((found == 1)) && Error "Could not get PPDM configuration from lockbox even though querying lockbox was successful, check logs"
    if ppdm_get_config_from_lockbox; then
        ((waiting == 1)) && ProgressStop
        let found=1 # continue with the while check to validate that indeed all 4 variables are not empty
    else
        if ((SECONDS > start_wait_for_lockbox + PPDM_WAIT_FOR_LOCKBOX_TIMEOUT)); then
            ProgressError
            Error "Timeout while waiting for working lockbox"
        fi
        if ((waiting == 0)); then
            LogPrint "Removing old CLB files to allow setting new lockbox"
            rm -fv $_PPDM_INSTALL_DIR/{agentsvc/config,fsagent/lockbox}/agents.clb*
            LogPrint \
                "PPDM Lockbox not usable, you must go to the PowerProtect Data Manager server
and perform the >Set Lockbox< action on the Protection Policy for this system
FQDN: $(hostname -f).
ReaR recovery can only continue after the lockbox is usable.
"
            ProgressStart
            let waiting=1
        else
            ProgressInfo "Waiting for $((SECONDS - start_wait_for_lockbox)) of $PPDM_WAIT_FOR_LOCKBOX_TIMEOUT seconds. "
            sleep 10
        fi
    fi
done

LogPrint "PPDM recovery configuration:
PPDM_DD_IP: $PPDM_DD_IP
PPDM_STORAGE_UNIT: $PPDM_STORAGE_UNIT
PPDM_DD_USERNAME: $PPDM_DD_USERNAME
PPDM_DD_CONFIG_TYPE: $PPDM_DD_CONFIG_TYPE
"
