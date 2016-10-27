# Setting required environment for DRLM proper function

if ! drlm_is_managed ; then
    return 0
fi

PROGS=( "${PROGS[@]}" curl )

# Needed for curl with NSS support
LIBS=( 
    "${LIBS[@]}"
    /usr/lib*/libsoftokn3.so* 
    /usr/lib*/libsqlite3.so* 
    /lib*/libfreeblpriv3.so*
    /usr/lib*/libfreeblpriv3.so*
)

drlm_import_runtime_config
