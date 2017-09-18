# ssh-agent shutdown during 'rear recover'
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

if [ -n "$SSH_AGENT_PID" ]; then
    Log "Shutting down ssh-agent"
    eval "$(ssh-agent -k)"
fi
