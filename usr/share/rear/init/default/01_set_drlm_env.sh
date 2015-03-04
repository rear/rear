# Setting required environment for DRLM proper function

if ! drlm_is_managed ; then
    return 0
fi

PROGS=( "${PROGS[@]}" curl )

# Needed for curl with NSS support
LIBS=( "${LIBS[@]}" /usr/lib64/libsoftokn3.so /usr/lib64/libsqlite3.so.0 /lib64/libfreeblpriv3.so )

drlm_import_runtime_config
