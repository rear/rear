# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

[[ -z "$DUPLY_PROFILE" ]] && return

# Same code in prep/DUPLICITY/default/200_find_duply_profile.sh
DebugPrint "Checking with 'duply $DUPLY_PROFILE status' if 'duply' can talk to the remote site"
Debug "'duply $DUPLY_PROFILE status' output:"
echo yes | duply "$DUPLY_PROFILE" status || Error "'duply $DUPLY_PROFILE status' failed, check $RUNTIME_LOGFILE"
