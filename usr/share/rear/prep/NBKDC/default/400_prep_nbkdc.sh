#
# prepare stuff for NovaStor DataCenter
#

function is_nbkdc_dir() {
  local candidate="$1"
  test -x $candidate/rcmd-executor/rcmd-executor
}

function find_nbkdc_dir() {
  for candidate in \
    "$NBKDC_DIR" \
    "$(readlink -f /proc/$(pgrep -nx rcmd-executor)/exe | sed 's/\/rcmd-executor*//g')" \
    "$(readlink /Hiback | sed 's/\/Hiback$//g')"
  do
    if is_nbkdc_dir "$candidate"; then
      NBKDC_DIR="$candidate"
      return 0
    fi
  done
  return 1
}

if find_nbkdc_dir; then
  Log "Detected NovaStor DC Installation in $NBKDC_DIR"
else
  LogPrintError "No NovaStor DataCenter Software installed"
  Error "No NBKDC found, exiting NBKDC prep"
fi

CLIENT_INI=$NBKDC_DIR/conf/client.properties
if [ -r "$CLIENT_INI" ]; then
  # Avoid ShellCheck false error indication
  # SC1097: Unexpected ==. For assignment, use =
  # for code like
  #   while IFS== read key value
  # by quoting the assigned character:
  while IFS='=' read key value ; do
      case "$key" in
          hiback_install_dir) NBKDC_HIB_DIR="$value" ;;
          hiback_version) NBKDC_HIB_VER="$value" ;;
      esac
  done <"$CLIENT_INI"
else
  # The client.properties is no longer installed with recent DataCenter
  # installations (8.0.0 or newer)
  NBKDC_HIB_DIR="$NBKDC_DIR/Hiback"
fi


COND=$NBKDC_HIB_DIR/CONDEV
[[ -r "$COND" ]] || Error "CONDEV file '$COND' can not be read"

# TODO: Explain what the CDV variable is
# cf. https://github.com/rear/rear/commit/4c8fd6f6aafbec9aacc94e704a2227f7fc4e3302#r68375270
# Avoid ShellCheck false error indication
# SC1097: Unexpected ==. For assignment, use =
# for code like
#   while IFS== read key value
# by quoting the assigned character:
while CDV='=' read key value ; do
    case "$key" in
        "&listdir:") NBKDC_HIBLST_DIR="$value" ;;
        "&tmpdir:") NBKDC_HIBTMP_DIR="$value" ;;
        "&tpddir:") NBKDC_HIBTPD_DIR="$value" ;;
        "&tapedir:") NBKDC_HIBTAP_DIR="$value" ;;
        "&msgdir:") NBKDC_HIBMSG_DIR="$value" ;;
        "&logdir:") NBKDC_HIBLOG_DIR="$value" ;;
        "&ssl-enabled:") NBKDC_HIBSSL_ENABLED="$value" ;;
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
NBKDC_HIB_SSL_ENABLED=$NBKDC_HIBSSL_ENABLED
EOF


# include DataCenter executables and configuration files 
COPY_AS_IS+=(
    "${COPY_AS_IS_NBKDC[@]}" 
    $NBKDC_DIR/etc/ssl
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
    $NBKDC_HIB_DIR/db2
    $NBKDC_HIB_DIR/onbar
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

# The files of NovaStor DataCenter installation belong to 'novastor'
TRUSTED_FILE_OWNERS+=(
    "${TRUSTED_FILE_OWNERS[@]}"
    novastor
)
