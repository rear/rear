# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

# here we will verify and add (if necessary) local backup directories to the EXCLUDE_RECREATE array.
# For the moment we only concentrate on BACKUP_URL=file:///path and add path to the above mentioned array
local scheme=$(url_scheme $BACKUP_URL)
local path=$(url_path $BACKUP_URL)

case $scheme in
     (file) # if user added path manually then there is no need to do it again
        _mntpt=$(df -P ${path} 2>/dev/null | tail -1 | awk '{print $6}')
        [[ "${_mntpt}" = "/" ]] && Error "Making backup on / is forbidden. Use an external device!"
        if ! grep -q "${_mntpt}" <<< $(echo ${EXCLUDE_RECREATE[@]}); then
                EXCLUDE_RECREATE=( "${EXCLUDE_RECREATE[@]}" "fs:${_mntpt}" )
        fi
        ;;
esac
