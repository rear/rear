### prepare stuff for BACULA
if ! test -d "$BACULA_CONF_DIR" ; then
    test -d "/etc/bacula" && BACULA_CONF_DIR="/etc/bacula"
    # bacula-enterprise-client uses /opt/bacula/etc
    test -d "/opt/bacula/etc" && BACULA_CONF_DIR="/opt/bacula/etc"
fi
test -d "$BACULA_CONF_DIR" || Error "No BACULA_CONF_DIR"
if ! test -d "$BACULA_BIN_DIR" ; then
    BACULA_BIN_DIR="/usr/sbin"
    # bacula-enterprise-client uses /opt/bacula/bin
    test -d "/opt/bacula/bin" && BACULA_BIN_DIR="/opt/bacula/bin"
fi
export PATH=$PATH:$BACULA_BIN_DIR
CLONE_GROUPS+=( bacula ) # default CLONE_ALL_USERS_GROUPS="true" in default.conf, but just in case...
COPY_AS_IS_BACULA+=( $BACULA_CONF_DIR )
COPY_AS_IS+=( "${COPY_AS_IS_BACULA[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_BACULA[@]}" )
PROGS+=( "${PROGS_BACULA[@]}" )

### Include mt when we are restoring from Bacula tape (for troubleshooting)
if [[ "$TAPE_DEVICE" || "$BEXTRACT_DEVICE" ]] ; then
    PROGS+=( mt )
fi
