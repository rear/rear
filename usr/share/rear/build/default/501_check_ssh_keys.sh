#
# Remove unprotected SSH keys inside the recovery system
# unless it is explicitly configured to keep them.
#

# Do nothing when it is explicitly configured to keep unprotected SSH keys:
is_true "$SSH_UNPROTECTED_PRIVATE_KEYS" && return

# Have a sufficiently secure fallback if SSH_UNPROTECTED_PRIVATE_KEYS is empty:
test "$SSH_UNPROTECTED_PRIVATE_KEYS" || SSH_UNPROTECTED_PRIVATE_KEYS='no'

# All paths must be relative paths inside the recovery system.
# Make the current working directory the recovery system ROOTFS_DIR.
# Caution: From here one cannot "just return" without 'popd' before.
pushd $ROOTFS_DIR

local key_files=()
# The funny [] around a letter makes 'shopt -s nullglob' remove this file from the list if it does not exist.
if is_false "$SSH_UNPROTECTED_PRIVATE_KEYS" ; then
    # When SSH_UNPROTECTED_PRIVATE_KEYS is false let ReaR find SSH key files:
    local host_key_files=( etc/ssh/ssh_host_* )
    # Caveat: This code will only detect SSH key files for root, not for other users.
    local root_key_files=( ./$ROOT_HOME_DIR/.ssh/identi[t]y ./$ROOT_HOME_DIR/.ssh/id_* )
    # Parse SSH config files in $ROOTFS_DIR/etc/ssh for non-commented IdentityFile keywords and values
    # (keywords are case-insensitive and values can be in double quotes and may have a single '=' separator, see "man ssh_config")
    # and replace in the IdentityFile values '~' in things like '~/.ssh/id_rsa' usually with '/root/.ssh/id_rsa'
    # (in default.conf $ROOT_HOME_DIR is '~root' which usually evaluates to '/root')
    # so for example in /etc/ssh/ssh_config entries like
    #   #   IdentityFile ~/.ssh/id_rsa
    #   IdentityFile    ~/.ssh/id_dsa
    #    IdentityFile = ~/.ssh/id_ecdsa
    #     identityfile "~/.ssh/id_ed25519"
    # would result
    #   /root/.ssh/id_dsa
    #   /root/.ssh/id_ecdsa
    #   /root/.ssh/id_ed25519
    # but the './' prefix for './$ROOT_HOME_DIR' in sed ... -e "s#~#./$ROOT_HOME_DIR#g"
    # makes the sed result match the above root_key_files=( ... ./$ROOT_HOME_DIR/.ssh/id_* )
    # which is e.g. .//root/.ssh/id_dsa so the above example actually results
    #   .//root/.ssh/id_dsa
    #   .//root/.ssh/id_ecdsa
    #   .//root/.ssh/id_ed25519
    # which ensures that all paths are relative paths inside the recovery system and
    # duplicates (e.g. $ROOTFS_DIR/.//root/.ssh/id_dsa and $ROOTFS_DIR//root/.ssh/id_dsa are the same file)
    # can be found and filtered out by the below key_files=( $( echo ... | sort -u ) )
    # The "find ./etc/ssh" ensures that SSH 'Include' config files e.g. in /etc/ssh/ssh_config.d/
    # are also parsed, cf. https://github.com/rear/rear/issues/2421
    local host_identity_files=( $( find ./etc/ssh -type f | xargs grep -ih '^[^#]*IdentityFile' | tr -d ' "=' | sed -e 's/identityfile//I' -e "s#~#./$ROOT_HOME_DIR#g" ) )
    # If $ROOTFS_DIR/root/.ssh/config exists parse it for IdentityFile values in the same way as above:
    local root_identity_files=()
    local root_ssh_config="./$ROOT_HOME_DIR/.ssh/config"
    test -s $root_ssh_config && root_identity_files=( $( grep -i '^[^#]*IdentityFile' $root_ssh_config | tr -d ' "=' | sed -e 's/identityfile//I' -e "s#~#./$ROOT_HOME_DIR#g" ) )
    # Combine the found key files:
    key_files=( $( echo "${host_key_files[@]}" "${root_key_files[@]}" "${host_identity_files[@]}" "${root_identity_files[@]}" | tr -s '[:space:]' '\n' | sort -u ) )
else
    # When SSH_UNPROTECTED_PRIVATE_KEYS is neither true nor false
    # it is interpreted as bash globbing patterns that match SSH key files.
    # It is crucial to not have quotes around ${SSH_UNPROTECTED_PRIVATE_KEYS[*]}
    # because with quotes the bash globbing patterns would not be evaluated here.
    # If the user specifies absolute paths it should not matter in the end because
    # then the bash globbing patterns are evaluated in the original system here
    # but below a leading slash gets removed from key files with absolute paths
    # which should result matching relative paths inside the recovery system:
    key_files=( ${SSH_UNPROTECTED_PRIVATE_KEYS[*]} )
fi

local removed_key_files=""
local key_file=""
for key_file in "${key_files[@]}" ; do
    # All paths must be relative paths inside the recovery system (see above)
    # but the user may have specified absolute paths in SSH_UNPROTECTED_PRIVATE_KEYS
    # or IdentityFile entries in etc/ssh/ssh_config and root/.ssh/config
    # may contain absolute paths so that a possibly leading slash is removed:
    key_file=${key_file#/}
    # To be safe against touching/modifying/removing any file in the original system
    # (below files get removed and that must never happen in the original system)
    # ROOTFS_DIR is prepended to work with absolute paths inside the recovery system
    # (nevertheless the current working directory is still ROOTFS_DIR to be 100% safe):
    test -s "$ROOTFS_DIR/$key_file" || continue
    # There is no simple way to check for unprotected SSH key files.
    # We therefore try to change the passphrase from empty to empty and if that succeeds then it is unprotected.
    # Because we do not want to try this with the key files in the original system to find unprotected keys
    # so that we could add unprotected key files to the COPY_AS_IS_EXCLUDE array in rescue/default/500_ssh.sh
    # we must do all that inside the recovery system so that we first copy key files into the recovery system
    # and afterwards we can here check for unprotected keys inside the recovery system and remove them there.
    # Run ssh-keygen silently with '-q' to suppress any output of it (also possible output directly to /dev/tty)
    # because it is used here only as a test, cf. https://github.com/rear/rear/pull/1530#issuecomment-336405425
    if ssh-keygen -q -p -P '' -N '' -f "$ROOTFS_DIR/$key_file" >/dev/null 2>&1 ; then
        rm -v "$ROOTFS_DIR/$key_file" 1>&2
        Log "Removed SSH key file '$key_file' from recovery system because it has no passphrase"
        removed_key_files+=" $key_file"
    else
        Log "SSH key file '$key_file' has a passphrase and is allowed in the recovery system"
    fi
done

test "$removed_key_files" && LogPrint "Removed SSH key files without passphrase from recovery system (SSH_UNPROTECTED_PRIVATE_KEYS not true):$removed_key_files"

# Go back out of the recovery system ROOTFS_DIR:
popd

