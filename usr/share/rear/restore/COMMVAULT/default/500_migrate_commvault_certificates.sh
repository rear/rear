# If commvault agent certificates are not copied, the agent will not work on the restored system

# copy certificates to the restored filesystem
rsync -a /opt/commvault/Base64/certificates $TARGET_FS_ROOT/opt/commvault/Base64/
