#
# Adapt some SSH configs and as needed regenerate SSH host key:

# There is nothing to do when there are no SSH binaries on the original system:
has_binary ssh || has_binary sshd || return 0

# Do nothing when not any SSH file should be copied into the recovery system:
is_false "$SSH_FILES" && return

# Patch sshd_config:
# Because only OpenSSH >= 3.1 is supported where /etc/ssh/ is the default directory for configuration files
# only etc/ssh/sshd_config is used cf. https://github.com/rear/rear/pull/1538#issuecomment-337904240
local sshd_config_file="$ROOTFS_DIR/etc/ssh/sshd_config"
if [[ -f "$sshd_config_file" ]]; then
    # Enable root login with a password only if SSH_ROOT_PASSWORD is set
    local password_authentication_value=no
    [[ -n "$SSH_ROOT_PASSWORD" ]] && password_authentication_value=yes

    # List of setting overrides required for the rescue system's sshd - see sshd_config(5)
    # Each list element must be a string of the form 'keyword [value]' or a comment '#...'.
    # If value is missing, the respective keyword will effectively be set to its default value.
    local sshd_setting_overrides=(
        # Start comment
        "### BEGIN ReaR overrides"
        # Avoid printing a message of the day, our /etc/profile does that
        "PrintMotd no"
        # Allow or disallow root login with a password
        "PasswordAuthentication $password_authentication_value"
        # Allow root login via SSH (authenticated via password or public/private keys)
        "PermitRootLogin yes"
        # Disable challenge response (Kerberos, skey, ...) as the rescue system does not provide it
        "ChallengeResponseAuthentication no"
        # Disable PAM as the rescue system does not provide it
        "UsePAM no"
        # Do not restrict interfaces to listen on, use defaults
        "ListenAddress"
        # Use default handling of idle messages
        "ClientAliveInterval"
        # End comment
        "### END ReaR overrides"
    )

    # Create sed options containing a list of commands to patch the existing sshd configuration file.
    local sed_patch_options=()
    local keyword value
    for sshd_option in "${sshd_setting_overrides[@]}"; do
        read -r keyword value <<<"$sshd_option"

        # When a value is specified: Insert a keyword/value setting at the top of the configuration.
        # This ensures that such settings are always part of the configuration's global section and not
        # of a possible 'Match' conditional block.
        [[ -n "$value" ]] && sed_patch_options+=("-e" "1i\\$keyword $value")

        # For each keyword (whether specified with a value or not): Comment out each setting elsewhere
        # in the configuration file. Note that there might be multiple occurrences of a keyword in the
        # configuration file and some might belong to 'Match' conditional blocks. We comment out all of
        # those to ensure that the global setting is always effective.
        if [[ "$keyword" != "#"* ]]; then
            sed_patch_options+=("-e" "s/^[ \\t]*${keyword}[ \\t].*/#& (ReaR override)/ig")
        fi
    done

    # Patch the sshd configuration file.
    sed -i "${sed_patch_options[@]}" "$sshd_config_file"

else
    LogPrintError "There is no sshd configuration at $sshd_config_file - logging into the rescue sytem via ssh may not work"
fi

# Create possibly missing directories needed by sshd in the recovery system
# cf. https://github.com/rear/rear/issues/1529
# To be on the safe side for other distributions we create these directories
# in the recovery system when they exist in the original system
# without distribution specific tests to make it work generically.
# In general why "Linux distribution specific scripts" will not really work
# see https://github.com/rear/rear/issues/1368#issuecomment-302410707
# At least on Red Hat /var/empty/sshd/etc with mode 0711 can be missing:
local sshd_needed_directory="var/empty/sshd/etc"
if test -d "/$sshd_needed_directory" ; then
    Log "Creating $sshd_needed_directory with mode 0711 (needed by sshd at least on Red Hat)"
    mkdir $v -p $ROOTFS_DIR/$sshd_needed_directory
    chmod $v 0711 $ROOTFS_DIR/$sshd_needed_directory
fi
# At least on Ubuntu /var/run/sshd can be missing:
sshd_needed_directory="var/run/sshd"
if test -d "/$sshd_needed_directory" ; then
    Log "Creating $sshd_needed_directory (needed by sshd at least on Ubuntu)"
    mkdir $v -p $ROOTFS_DIR/$sshd_needed_directory
fi

# Generate new SSH protocol version 2 host keys in the recovery system
# when no SSH host key file of the key types rsa, dsa, ecdsa, and ed25519
# had been copied into the the recovery system in rescue/default/500_ssh.sh
# cf. https://github.com/rear/rear/issues/1512#issuecomment-331638066
# but skip that if SSH_UNPROTECTED_PRIVATE_KEYS is false
# because private host keys are never protected
# cf. https://github.com/rear/rear/pull/1530#issuecomment-336636983
is_false "$SSH_UNPROTECTED_PRIVATE_KEYS" && return
# In SLES12 "man ssh-keygen" reads:
#   -t dsa | ecdsa | ed25519 | rsa | rsa1
#      Specifies the type of key to create.
#      The possible values are "rsa1" for protocol version 1
#      and "dsa", "ecdsa", "ed25519", or "rsa" for protocol version 2.
# The above GitHub issue comment proposes a static
#   ssh-keygen -t ed25519 -N '' -f "..."
# but the key type ed25519 is not supported in older systems like SLES11.
# On SLES10 "man ssh-keygen" reads:
#   -t type
#      Specifies the type of key to create.
#      The possible values are rsa1 for protocol version 1
#      and rsa or dsa for protocol version 2.
# Currently (October 2017) ReaR is kept working on older systems
# like SLES10 cf. https://github.com/rear/rear/issues/1522
# and currently this backward compatibility should not be broken
# (for the future see https://github.com/rear/rear/issues/1390)
# so that we try to generate all possible types of keys provided
# the particular type of key also exists on the original system.
# For example what there is on a default SLES system:
# On a default SLES10 there is
#  /etc/ssh/ssh_host_key
#  /etc/ssh/ssh_host_key.pub
#  /etc/ssh/ssh_host_dsa_key
#  /etc/ssh/ssh_host_dsa_key.pub
#  /etc/ssh/ssh_host_rsa_key
#  /etc/ssh/ssh_host_rsa_key.pub
# On a default SLES11 there is additionally
#  /etc/ssh/ssh_host_ecdsa_key
#  /etc/ssh/ssh_host_ecdsa_key.pub
# On a default SLES12 there is additionally
#  /etc/ssh/ssh_host_ed25519_key
#  /etc/ssh/ssh_host_ed25519_key.pub
# The old rsa1 type for SSH protocol version 1 is not supported here.
# Only SSH protocol version 2 (the default since 2001) is supported:
local ssh_host_key_types="rsa dsa ecdsa ed25519"
local ssh_host_key_type=""
local ssh_host_key_file=""
local recovery_system_key_file=""
local ssh_host_key_exists="no"
for ssh_host_key_type in $ssh_host_key_types ; do
    ssh_host_key_file="etc/ssh/ssh_host_${ssh_host_key_type}_key"
    # Do not overwrite what is already there (could have been copied via COPY_AS_IS):
    if test -f "$ROOTFS_DIR/$ssh_host_key_file" ; then
        Log "Using existing SSH host key $ssh_host_key_file in recovery system"
        ssh_host_key_exists="yes"
        continue
    fi
    # Only generate the particular type of key if it also exists on the original system
    # because it is no longer recommended to use host keys other than rsa and ed25519,
    # see section 2.2.1 in https://bettercrypto.org/static/applied-crypto-hardening.pdf
    # and generating old-style host keys will only help with ssh clients which are
    # very old (OpenSSH versions < 2.9), see https://www.openssh.com/releasenotes.html
    # cf. https://github.com/rear/rear/pull/1530#discussion_r143948453
    if ! test -f "/$ssh_host_key_file" ; then
        Log "Skip generating $ssh_host_key_type type key because there is no /$ssh_host_key_file on the original system"
        continue
    fi
    Log "Generating new SSH host key $ssh_host_key_file in recovery system"
    recovery_system_key_file="$ROOTFS_DIR/$ssh_host_key_file"
    mkdir $v -p $( dirname "$recovery_system_key_file" )
    # Running ssh-keygen with '$v' as usual in ReaR does not reveal possibly confidential information
    # cf. https://github.com/rear/rear/pull/1530#issuecomment-336405425
    ssh-keygen $v -t "$ssh_host_key_type" -N '' -f "$recovery_system_key_file" && ssh_host_key_exists="yes" || Log "Cannot generate $ssh_host_key_type key"
done
is_false "$ssh_host_key_exists" && LogPrintError "No SSH host key etc/ssh/ssh_host_TYPE_key of any type $ssh_host_key_types in recovery system"

