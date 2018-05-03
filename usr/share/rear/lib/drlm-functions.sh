# drlm-functions.sh
#
# DRLM functions for Relax-and-Recover
#

# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

function drlm_import_runtime_config() {

    for arg in "${ARGS[@]}" ; do
        key=DRLM_"${arg%%=*}"
        val="${arg#*=}"
        eval $key='$val'
        Log "Setting $key=$val"
    done

    if ! has_binary curl ; then
        Error "DRLM_MANAGED: Need 'curl' to download DRLM dynamic configuration. Please install curl and try again."
    fi

    if [[ "$DRLM_SERVER" && "$DRLM_REST_OPTS" && "$DRLM_ID" ]]; then
        if [ "$CONFIG_APPEND_FILES" ]; then
            for config_append_file in $CONFIG_APPEND_FILES ; do
                LogPrint "DRLM_MANAGED: Loading configuration '$config_append_file' from DRLM ..."
                local DRLM_CFG="/tmp/$config_append_file"
                local http_response_code=$(curl $verbose -f -s -S -w '%{http_code}' $DRLM_REST_OPTS -o $DRLM_CFG https://$DRLM_SERVER/clients/$DRLM_ID/config/$config_append_file)
                test "200" = "$http_response_code" || Error "DRLM_MANAGED: curl failed with HTTP response code '$http_response_code' trying to load '$config_append_file' from DRLM."
                source $DRLM_CFG
                rm $DRLM_CFG
            done
        else
            LogPrint "DRLM_MANAGED: Loading configuration from DRLM ..."
            local DRLM_CFG="/tmp/drlm_config"
            local http_response_code=$(curl $verbose -f -s -S -w '%{http_code}' $DRLM_REST_OPTS -o $DRLM_CFG https://$DRLM_SERVER/clients/$DRLM_ID/config)
            test "200" = "$http_response_code" || Error "DRLM_MANAGED: curl failed with HTTP response code '$http_response_code' trying to load configuration from DRLM."
            source $DRLM_CFG
            rm $DRLM_CFG
        fi
    else
        Error "DRLM_MANAGED: Please be sure DRLM_SERVER, DRLM_REST_OPTS and DRLM_ID are properly defined in local.conf or at set them at runtime (see: default.conf)"
    fi

}

function drlm_send_log() {

    # send log file in real time to DRLM
    LogPrint "DRLM_MANAGED: Sending Logfile: '$RUNTIME_LOGFILE' to DRLM in real time ..."
    ( tail -f --lines=5000 --pid=$$ $RUNTIME_LOGFILE | curl $verbose -T- -f -s -S $DRLM_REST_OPTS https://$DRLM_SERVER/clients/$DRLM_ID/log/$WORKFLOW/$(date +%Y%m%d%H%M%S) ) &

}
