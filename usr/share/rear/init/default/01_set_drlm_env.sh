# Setting required environment for DRLM proper function

if ! drlm_is_managed ; then
    return 0
fi

PROGS=( "${PROGS[@]}" curl )

drlm_import_runtime_config

if [[ "$OUTPUT" == "PXE" ]]; then
    OUTPUT_PREFIX_PXE="$DRLM_CLIENT/$OUTPUT_PREFIX"
fi
