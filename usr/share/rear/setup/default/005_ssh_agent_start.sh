# If available, start ssh-agent so that SSH passphrases must be entered only once during 'rear recover' even with
# multiple ssh invocations (as may be the case when restoring from a network backup server).
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

if has_binary ssh-agent && has_binary ssh && grep -iq AddKeysToAgent "$(type -P ssh)" ; then
    # Use ssh-agent only if ssh supports the AddKeysToAgent option. Otherwise, we'd have to use ssh-add to
    # register keys for repeated use but we don't know which keys might be required during 'rear recover'.

    Log "Starting up ssh-agent"

    AddExitTask "ssh-agent -k >/dev/null"
    eval "$(ssh-agent -s)"

    echo -e "\nHost *\nAddKeysToAgent yes\n" >> $ROOT_HOME_DIR/.ssh/config
fi
