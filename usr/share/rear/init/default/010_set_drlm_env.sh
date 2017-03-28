# Setting required environment for DRLM proper function

is_true "$DRLM_MANAGED" || return 0

drlm_import_runtime_config
drlm_send_log
