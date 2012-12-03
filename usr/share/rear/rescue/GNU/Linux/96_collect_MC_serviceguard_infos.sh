# 96_collect_MC_serviceguard_infos.sh
# Purpose of this script is to gather MC/SG related config files
# in order to prepare a smooth rolling upgrade

# List files and directories in SGLX_FILES
SGLX_FILES="/etc/hostname
/etc/vconsole.conf
/etc/locale.conf
/etc/sysconfig/keyboard
/etc/sysconfig/network-scripts/ifcfg*
/etc/sysconfig/network/ifcfg*
/etc/sysconfig/network
/etc/hosts
/etc/modprobe.conf
/etc/modules.conf
/etc/cmcluster.conf
/etc/hp_qla2x00.conf
/etc/lpfc.conf
/etc/ntp.conf
/etc/resolv.conf
/usr/local/cmcluster/conf/*/*
/opt/cmcluster/conf/*/*"

# Phase 1 : does sglx soft is installed?
# on RH path is /usr/local/cmcluster; on SuSe path is /opt/cmcluster
[ -d /usr/local/cmcluster/conf -o -d /opt/cmcluster/conf ] || return

# Phase 2: create a /etc/rear/recovery/sglx directory
mkdir -p $v -m755 "$VAR_DIR/recovery/sglx" >&2
StopIfError "Could not create sglx configuration directory: $VAR_DIR/recovery/sglx"

SGLX_DIR="$VAR_DIR/recovery/sglx"

for sgf in $SGLX_FILES
do
	if [ `dirname ${sgf}` != . ]; then
		mkdir -p $v ${SGLX_DIR}/`dirname ${sgf}` >&2
	fi
	if [ -f ${sgf} ]; then
		cp $v ${sgf} ${SGLX_DIR}${sgf} >&2
	fi
done
