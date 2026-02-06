# Script 055_error_on_duplicity_gpg_options.sh
#
# Using BACKUP_DUPLICITY_GPG_OPTIONS setting in /etc/rear/local.conf is not allowed anymore
# due to unreliable behavior during backup/restore phase.
# Instead define the GnuPG non-default options in the ~/.gnupg/gpg.conf file, e.g.
# to define another cipher algorithm then the default aes128 you could create: 
# $ cat ~/.gnupg/gpg.conf 
# cipher-algo aes256
#
# To see all available gpg options: gpg --version

[[ -n "$BACKUP_DUPLICITY_GPG_OPTIONS" ]] && Error "
Do not use BACKUP_DUPLICITY_GPG_OPTIONS variable in the ReaR config files.
Instead define the gpg options in the ~/.gnupg/gpg.conf file.
"
