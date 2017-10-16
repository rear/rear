#
# Remove unprotected SSH keys from the recovery system
# unless it is explicitly configured to keep them.
#
is_true "$SSH_UNPROTECTED_PRIVATE_KEYS" && return

local host_key_files=( $ROOTFS_DIR/etc/ssh/ssh_ho[s]t_* )
# Caveat: This code will only detect SSH key files for root, not for other users.
local root_key_files=( $ROOTFS_DIR/root/.ssh/{identity,id_dsa,id_ecdsa,id_ed25519,id_rsa} )
# Parse etc/ssh/ssh_config and root/.ssh/config to find more key files in the recovery system:
local more_key_files="$( sed -n -e "s#~#$ROOTFS_DIR/root#g" \
                                -e '/^[^#]*identityfile/Is/^.*identityfile[ ]\+\([^ ]\+\).*$/\1/ip' \
                             $ROOTFS_DIR/etc/ssh/ssh_co[n]fig $ROOTFS_DIR/root/.ssh/co[n]fig </dev/null | sort -u )"

local key_files=( "${host_key_files[@]}" "${root_key_files[@]}" "${more_key_files[@]}" )

# Nothing to do when no key files were found:
test "${key_files[*]}" || return

local removed_keys=0
local key_file=""
for key_file in "${key_files[@]}" ; do
    test -s "$key_file" || continue
    display_key_file=${key_file#$ROOTFS_DIR}
    # There is no simple way to check for unprotected SSH key files.
    # We therefore try to change the passphrase from empty to empty and if that succeeds then it is unprotected.
    # Run ssh-keygen silently with '-q' to suppress any output of it (also possible output directly to /dev/tty)
    # because it is used here only as a test, cf. https://github.com/rear/rear/pull/1530#issuecomment-336405425
    if ssh-keygen -q -p -P '' -N '' -f "$key_file" >/dev/null 2>&1 ; then
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

