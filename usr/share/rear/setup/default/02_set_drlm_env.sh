# Setting required environment for DRLM proper function

if ! drlm_is_managed ; then
    return 0
fi

drlm_import_runtime_config
