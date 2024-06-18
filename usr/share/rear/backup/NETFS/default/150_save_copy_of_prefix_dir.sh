# if NETFS_KEEP_OLD_BACKUP_COPY is not empty then move old NETFS_PREFIX directory to NETFS_PREFIX.old

[ -z "${NETFS_KEEP_OLD_BACKUP_COPY}" ] && return

# do not do this for tapes and special attention for file:///path
local scheme="$( url_scheme "$BACKUP_URL" )"
local path="$( url_path "$BACKUP_URL" )"
local opath="$( backup_path "$scheme" "$path" )"

# if $opath is empty return silently (e.g. scheme tape)
[ -z "$opath" ] && return 0

if ! test -f "${opath}/.lockfile" ; then
    if test -d "${opath}" ; then
        rm -rf $v "${opath}.old" || Error "Could not remove '${opath}.old'"
        mv -f $v "${opath}" "${opath}.old" || Error "Could not move '${opath}'"
    fi
else
    # lockfile was already made through the output workflow (hands off)
    Log "Lockfile '${opath}/.lockfile' found (created by output workflow)."
fi
# the ${BUILD_DIR}/outputfs/${NETFS_PREFIX} will be created by backup/NETFS/default/200_make_prefix_dir.sh
