#
# prepare stuff for NovaBACKUP DataCenter
#

# detect where and if DataCenter client is installed on the system running
# REAR and include the needed bits in the recovery ISO

if [ ! -f "$NBKDC_DIR/conf/client.properties" ]; then
    NBKDC_DIR=$(readlink -f /proc/$(pgrep -nx rcmd-executor)/exe | sed 's/\/rcmd-executor*//g')
    if  [ ! -f "$NBKDC_DIR/conf/client.properties" ] ; then
        LogUserOutput "Cannot find running NovaBACKUP DataCenter Agent!!"
        LogUserOutput "Locating the NovaBACKUP DataCenter Agent via /Hiback"
        NBKDC_DIR=$(readlink /Hiback | sed 's/\/Hiback$//g')
        if [ ! -f "$NBKDC_DIR/conf/client.properties" ]; then
            LogPrintError "No NovaBACKUP DataCenter Software installed"
            Error "No NBKDC found, exiting NBKDC prep"
        fi
    fi
fi

Log "Detected NovaBACKUP DC Installation in $NBKDC_DIR"

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


# include DataCenter executables and configuration files 
COPY_AS_IS+=(
    "${COPY_AS_IS_NBKDC[@]}" 
    $NBKDC_DIR/conf
    $NBKDC_DIR/log
    $NBKDC_DIR/rcmd-executor 
    $NBKDC_HIB_DIR 
)

# do not include certain DataCenter folders as generated boot
# image will grow too big if DataCenter listing and temporary
# files are included
COPY_AS_IS_EXCLUDE+=(
    "${COPY_AS_IS_EXCLUDE_NBKDC[@]}"
    $NBKDC_DIR/rcmd-executor/tmp/*        
    $NBKDC_DIR/log/*
    $NBKDC_HIBTMP_DIR 
    $NBKDC_HIBLIS_DIR 
    $NBKDC_HIBTPD_DIR/*.tpd
    $NBKDC_HIB_DIR/ora* 
    $NBKDC_HIB_DIR/ndmp 
    $NBKDC_HIB_DIR/mm 
    $NBKDC_HIB_DIR/hui 
    $NBKDC_HIB_DIR/stp
    $NBKDC_HIB_DIR/svn
    $NBKDC_HIB_DIR/vmgr
    $NBKDC_HIB_DIR/svm
    /var/run/rcmd-executor.pid
)
