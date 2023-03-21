# If commvault agent certificates are not copied, the agent will not work on the restored system

local certs="$GALAXY11_HOME_DIRECTORY/certificates"
# copy certificates to the restored filesystem
if test -d $certs; then
    cp -a $certs "$TARGET_FS_ROOT/$GALAXY11_HOME_DIRECTORY" || Error "Could not copy $certs"
fi
