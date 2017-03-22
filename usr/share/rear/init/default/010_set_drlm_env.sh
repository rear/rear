# Setting required environment for DRLM proper function

is_true "$DRLM_MANAGED" || return 0

# Needed for curl (HTTPs)
COPY_AS_IS=( ${COPY_AS_IS[@]} /etc/ssl/certs/* /etc/pki/* )

LIBS=(
    "${LIBS[@]}"
    /lib*/libnsspem.so*
    /usr/lib*/libnsspem.so*
    /lib*/libfreebl*.so*
    /usr/lib*/libfreebl*.so*
    /lib*/libnss3.so*
    /usr/lib*/libnss3.so*
    /lib*/libnssutil3.so*
    /usr/lib*/libnssutil3.so*
    /lib*/libsoftokn3.so*
    /usr/lib*/libsoftokn3.so*
    /lib*/libsqlite3.so*
    /usr/lib*/libsqlite3.so*
    /lib*/libfreeblpriv3.so*
    /usr/lib*/libfreeblpriv3.so*
    /lib*/libssl.so*
    /usr/lib*/libssl.so*
    /lib*/libnssdbm3.so*
    /usr/lib*/libnssdbm3.so*
)

drlm_import_runtime_config
drlm_send_log
