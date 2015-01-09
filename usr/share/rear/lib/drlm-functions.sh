# drlm-functions.sh
#
# DRLM functions for Relax-and-Recover
#

# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

function drlm_check() {

	if [ -z $DRLM_PREFIX ] || [ -z $DRLM_OPTS1 ] || [ -z $DRLM_OPTS2 ]; then
		return 1
	else
		return 0
	fi

}

function drlm_set_rear_config() {

	DRLM_VAR=($(echo $DRLM_OPTS1|tr ";" " "))
	DRLM_VAL=($(echo $DRLM_OPTS2|tr ";" " "))

	for ((i = 0; i < ${#DRLM_VAR[@]}; i++))
	do
		val=($(echo ${DRLM_VAL[$i]}|tr "," " "))
		if [ "$val" != "UNSET" ]; then
			eval "${DRLM_VAR[$i]}=(\${val[@]})"
		fi
	done

}

function drlm_set_rescue_conf() {

	DRLM_VAR=($(echo $DRLM_OPTS1|tr ";" " "))
	DRLM_VAL=($(echo $DRLM_OPTS2|tr ";" " "))

	for ((i = 0; i < ${#DRLM_VAR[@]}; i++))
	do
		val=($(echo ${DRLM_VAL[$i]}|tr "," " "))
		if [ "$val" != "UNSET" ]; then
			echo "${DRLM_VAR[$i]}=(${val[@]})" | tee -a $ROOTFS_DIR/etc/rear/rescue.conf
		fi
	done

}
