# remove unprotected SSH keys unless configured to keep them
is_true "$SSH_UNPROTECTED_PRIVATE_KEYS" && return

# caveat: this code will only detect SSH key files for root, not for other users
key_files=(
    $ROOTFS_DIR/root/.ssh/{identity,id_dsa,id_ecdsa,id_ed25519,id_rsa}
    # Parse /etc/ssh/ssh_config and /root/.ssh/config for more keys files
    $(
    sed -n -e "s#~#$ROOTFS_DIR/root#g" \
        -e '/^[^#]*identityfile/Is/^.*identityfile[ ]\+\([^ ]\+\).*$/\1/ip' \
        $ROOTFS_DIR/etc/ssh/ssh_co[n]fig $ROOTFS_DIR/root/.ssh/co[n]fig </dev/null | \
    sort -u
    )
)
: ${key_files[@]}

local removed_keys=0
for key_file in "${key_files[@]}" ; do
    test -s "$key_file" || continue
    display_key_file=${key_file#$ROOTFS_DIR}
    # There is no simple way to check for unprotected SSH key files.
    # We therefore try to change the passphrase from empty to empty and if that succeeds then it is unprotected
    if ssh-keygen -q -p -P '' -N '' -f "$key_file" >/dev/null 2>&1; then
        # Handle the unprotected private key file
        Log "Removed private SSH key '$display_key_file' from rescue media because it has no passphrase"
        rm -v "$key_file" 1>&2
        let removed_keys++
    else
        Log "Private SSH key '$display_key_file' has a passphrase and is allowed on the rescue media"
    fi
done

if (( removed_keys > 0 )) ; then
    LogPrint "Removed $removed_keys unprotected SSH keys from the rescue media, set SSH_UNPROTECTED_PRIVATE_KEYS=yes to keep them"
fi
