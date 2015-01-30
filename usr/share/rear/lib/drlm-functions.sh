# drlm-functions.sh
#
# DRLM functions for Relax-and-Recover
#

# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

function drlm_is_managed() {

    if [[ "$DRLM_MANAGED" == "y" ]]; then
        return 0
    else
        return 1
    fi

}

function drlm_import_runtime_config() {

    for arg in "${ARGS[@]}" ; do
        key=DRLM_"${arg%%=*}"
        val="${arg#*=}"
        declare $key="$val"
        Log "Setting $key=$val"
    done

    if ! has_binary curl ; then
        Error "Need 'curl' to download DRLM dynamic configuration. Please install curl and try again."
    fi

    if [[ "$DRLM_SERVER" && "$DRLM_REST_OPTS" && "$DRLM_ID" ]]; then
        DRLM_CFG=$(curl $DRLM_REST_OPTS https://$DRLM_SERVER/clients/$DRLM_ID)
        eval "$DRLM_CFG"
    else
        Error "ReaR only can be run from DRLM Server ('DRLM_MANAGED=y' is set)"
    fi

}
