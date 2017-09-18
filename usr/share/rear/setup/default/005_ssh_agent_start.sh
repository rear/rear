# If available, start ssh-agent so that SSH passphrases must be entered only once during 'rear recover' even with
# multiple ssh invocations (as may be the case when restoring from a network backup server).
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

if has_binary ssh-agent; then
    Log "Starting up ssh-agent"
    eval "$(ssh-agent -s)"
    echo -e "\nHost *\nAddKeysToAgent yes\n" >> /root/.ssh/config
fi
