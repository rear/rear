# locate NovaBACKUP DC client configuration, referenced by
#
# prep/NBKDC/default/40_prep_nbkdc.sh
# skel/NBKDC/etc/scripts/system-setup.d/59-start-nbkdc-client.sh


# Set the NovaBACKUP DC default directory
NBKDC_DIR=/opt/NovaStor/DataCenter


function get_nbkdc_dir() {

# check for running process rcmd-executor to determine its parent path
NBKDC_DIR=$(ps -ef | grep rcmd-executor | grep -v grep | awk -F\  '{print $8}' | sed 's/\/rcmd-executor*//g')
   if  [ ! -d "$NBKDC_DIR" ] ; then
       echo "Cannot find running NovaBACKUP DataCenter Agent!!"
       exit 2
   fi
}


[[ ! -d "$NBKDC_DIR" ]] && get_nbkdc_dir


CLIENT_INI=$NBKDC_DIR/conf/client.properties
[[ -z "$CLIENT_INI" ]] && return

while IFS== read key value ; do
    case "$key" in
        hiback_install_dir) NBKDC_HIB_DIR="$value" ;;
	hiback_version) NBKDC_HIB_VER="$value" ;;
    esac
done <"$CLIENT_INI"

#NBKDC_HIBTMP_DIR=$(grep  "^\&tmpdir" $NBKDC_HIB_DIR/CONDEV | awk -F: '{print $2}' | sed -e "s+ ++g")
#NBKDC_HIBLOG_DIR=$(grep  "^\&logdir" $NBKDC_HIB_DIR/CONDEV | awk -F: '{print $2}' | sed -e "s+ ++g")
#NBKDC_HIBLST_DIR=$(grep  "^\&listdir" $NBKDC_HIB_DIR/CONDEV | awk -F: '{print $2}' | sed -e "s+ ++g")
#NBKDC_HIBMSG_DIR=$(grep  "^\&msgdir" $NBKDC_HIB_DIR/CONDEV | awk -F: '{print $2}' | sed -e "s+ ++g")
#NBKDC_HIBTPD_DIR=$(grep  "^\&tpddir" $NBKDC_HIB_DIR/CONDEV | awk -F: '{print $2}' | sed -e "s+ ++g")

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

