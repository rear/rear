# read sesam configuration values, referenced by
#
# prep/SESAM/default/400_prep_sesam.sh
# skel/SESAM/etc/scripts/system-setup.d/59-start-sesam-client.sh

sesam2000ini_file="/etc/sesam2000.ini"

if ! test -r $sesam2000ini_file ; then
    return 0
fi

# for later use in build/default/990_verify_rootfs.sh to avoid issues
# with missing library dependencies during rootfs check
source $sesam2000ini_file
SESAM_LD_LIBRARY_PATH=$SM_BIN_SESAM:$SM_BIN_SESAM/python3/:$SM_BIN_SMS

SM_INI="$( grep SM_INI $sesam2000ini_file 2>/dev/null | cut -d '=' -f 2 )"
test -r "$SM_INI" -a -f "$SM_INI" || SM_INI=/dev/null

# set SESAM_*_DIR variables to values from sm.ini (with trailing slashes removed!)

# Avoid ShellCheck false error indication
# SC1097: Unexpected ==. For assignment, use =
# for code like
#   while IFS== read key value
# by quoting the assigned character:
while IFS='=' read key value ; do
    case "$key" in
        (gv_ro)      SESAM_BIN_DIR="${value%%/}" ;;
        (gv_rw)      SESAM_VAR_DIR="${value%%/}" ;;
        (gv_rw_work) SESAM_WORK_DIR="${value%%/}" ;;
        (gv_rw_tmp)  SESAM_TMP_DIR="${value%%/}" ;;
        (gv_rw_lis)  SESAM_LIS_DIR="${value%%/}" ;;
        (gv_rw_lgc)  SESAM_LGC_DIR="${value%%/}" ;;
        (gv_rw_stpd) SESAM_SMS_DIR="${value%%/}" ;;
        (gv_rw_prot) SESAM_PROT_DIR="${value%%/}" ;;
    esac
done <"$SM_INI"

# set variables to default values if automatic setting did not work
# (e.g. gv_rw_lis, gv_rw_stpd and gv_rw_prot do not exist on sesam clients)
# to prevent 'everything' excludes "/*" in 400_prep_sesam.sh
test -z "${SESAM_BIN_DIR}"  && SESAM_BIN_DIR=/opt/sesam
test -z "${SESAM_VAR_DIR}"  && SESAM_VAR_DIR=/var/opt/sesam
test -z "${SESAM_WORK_DIR}" && SESAM_WORK_DIR=${SESAM_VAR_DIR}/var/work
test -z "${SESAM_TMP_DIR}"  && SESAM_TMP_DIR=${SESAM_VAR_DIR}/var/tmp
test -z "${SESAM_LIS_DIR}"  && SESAM_LIS_DIR=${SESAM_VAR_DIR}/var/lis
test -z "${SESAM_LGC_DIR}"  && SESAM_LGC_DIR=${SESAM_VAR_DIR}/var/log/lgc
test -z "${SESAM_SMS_DIR}"  && SESAM_SMS_DIR=${SESAM_VAR_DIR}/var/log/sms
test -z "${SESAM_PROT_DIR}" && SESAM_PROT_DIR=${SESAM_VAR_DIR}/var/prot

