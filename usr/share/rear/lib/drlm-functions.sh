# drlm-functions.sh
#
# DRLM functions for Relax-and-Recover
#

# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

function drlm_is_managed() {

	if [ "$DRLM_MANAGED" == "y" ]; then
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

	if [ $DRLM_SERVER ] && [ $DRLM_USER ] && [ $DRLM_PASS ] && [ $DRLM_CLIENT ]; then
		DRLM_CFG=$(curl -X POST -k -u $DRLM_USER:$DRLM_PASS -d "client=$DRLM_CLIENT" https://$DRLM_SERVER/getconfig)
		eval "$DRLM_CFG"
	else
		Error "ReaR only can be run from DRLM Server ('DRLM_MANAGED=y' is set)"
	fi

}
