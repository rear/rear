# What do we do when variable BACKUP_DUPLICITY_GPG_ENC_PASSPHRASE is not set?

# During recover we ask the passphrase when BACKUP_DUPLICITY_ASK_PASSPHRASE=true.
# Or, BACKUP_DUPLICITY_GPG_ENC_PASSPHRASE was defined in the ReaR config files.
# Therefore, we will skip the check while we are in the 'recover' workflow:
[[ "$WORKFLOW" = "recover" ]] && return

if [[ "$WORKFLOW" = "mkbackup" ]] || [[ "$WORKFLOW" = "mkbackuponly" ]] ; then
    # If BACKUP_DUPLICITY_GPG_ENC_PASSPHRASE is not set in the ReaR config files we complain
    [[ -z "$BACKUP_DUPLICITY_GPG_ENC_PASSPHRASE" ]] && Error "
Variable BACKUP_DUPLICITY_GPG_ENC_PASSPHRASE was not defined in ReaR config file.
    "
fi
