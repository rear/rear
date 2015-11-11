# locate NovaBACKUP DC client configuration, referenced by
#
# prep/NBKDC/default/40_prep_nbkdc.sh

function get_nbkdc_dir() {

# check for running process rcmd-executor to determine its parent path
# NBKDC_DIR=$(ps -ef | grep rcmd-executor | grep -v grep | awk -F\  '{print $8}' | sed 's/\/rcmd-executor*//g')
NBKDC_DIR=$(readlink -f /proc/$(pgrep -nx rcmd-executor)/exe | sed 's/\/rcmd-executor*//g')
    if  [ ! -d "$NBKDC_DIR" ] ; then
        echo "Cannot find running NovaBACKUP DataCenter Agent!!"
        exit 2
    fi
}

# The NovaBACKUP DC default directory should be set from the default.conf
# NBKDC_DIR=/opt/NovaStor/DataCenter

[[ ! -d "$NBKDC_DIR" ]] && get_nbkdc_dir


CLIENT_INI=$NBKDC_DIR/conf/client.properties
[[ -z "$CLIENT_INI" ]] && return

while IFS== read key value ; do
    case "$key" in
        hiback_install_dir) NBKDC_HIB_DIR="$value" ;;
        hiback_version) NBKDC_HIB_VER="$value" ;;
    esac
done <"$CLIENT_INI"


COND=$NBKDC_HIB_DIR/CONDEV
[[ -z "$COND" ]] && return

while CDV== read key value ; do
    case "$key" in
        "&listdir:") NBKDC_HIBLST_DIR="$value" ;;
        "&tmpdir:") NBKDC_HIBTMP_DIR="$value" ;;
        "&tpddir:") NBKDC_HIBTPD_DIR="$value" ;;
        "&tapedir:") NBKDC_HIBTAP_DIR="$value" ;;
        "&msgdir:") NBKDC_HIBMSG_DIR="$value" ;;
        "&logdir:") NBKDC_HIBLOG_DIR="$value" ;;
    esac
done <"$COND"

# Now generate nbkdc_settings for use during the rescue stage
cat >$VAR_DIR/recovery/nbkdc_settings <<-EOF
NBKDC_DIR=$NBKDC_DIR
NBKDC_HIB_DIR=$NBKDC_HIB_DIR
NBKDC_HIB_LST=$NBKDC_HIBLST_DIR
NBKDC_HIB_TMP=$NBKDC_HIBTMP_DIR
NBKDC_HIB_TPD=$NBKDC_HIBTPD_DIR
NBKDC_HIB_TAP=$NBKDC_HIBTAP_DIR
NBKDC_HIB_MSG=$NBKDC_HIBMSG_DIR
NBKDC_HIB_LOG=$NBKDC_HIBLOG_DIR
EOF
