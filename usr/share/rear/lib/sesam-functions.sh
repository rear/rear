# read sesam configuration values, referenced by
#
# prep/SESAM/default/40_prep_sesam.sh
# skel/SESAM/etc/scripts/system-setup.d/59-start-sesam-client.sh

sesam2000ini_file="/etc/sesam2000.ini"

if ! test -r $sesam2000ini_file ; then
    return 0
fi

SM_INI="$( grep SM_INI $sesam2000ini_file 2>/dev/null | cut -d '=' -f 2 )"
test -z "$SM_INI" && return 0

while IFS== read key value ; do
    case "$key" in
        (gv_ro) SESAM_BIN_DIR="$value" ;;
        (gv_rw) SESAM_VAR_DIR="$value" ;;
        (gv_rw_work) SESAM_WORK_DIR="$value" ;;
        (gv_rw_tmp) SESAM_TMP_DIR="$value" ;;
        (gv_rw_lis) SESAM_LIS_DIR="$value" ;;
        (gv_rw_lgc) SESAM_LGC_DIR="$value" ;;
        (gv_rw_work) SESAM_WORK_DIR="$value" ;;
        (gv_rw_stpd) SESAM_SMS_DIR="$value" ;;
        (gv_rw_prot) SESAM_PROT_DIR="$value" ;;
    esac
done <"$SM_INI"

