# copy_fstab_file
# purpose is to copy the /etc/fstab file as we will use it during the recover phase
# e.g. to retrieve the LABEL information
cp /etc/fstab "${VAR_DIR}/recovery/fstab" || Error "Could not copy [Error $?] to fstab file"
