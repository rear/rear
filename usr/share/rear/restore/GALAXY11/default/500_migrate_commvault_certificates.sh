# If commvault agent certificates are not copied, the agent will not work on the restored system

local commvault_base_dir=/opt/commvault/Base64
local certs=$commvault_base_dir/certificates
# copy certificates to the restored filesystem
if test -d $certs; then
    cp -a $certs "$TARGET_FS_ROOT/$commvault_base_dir" || Error "Could not copy $certs"
fi
