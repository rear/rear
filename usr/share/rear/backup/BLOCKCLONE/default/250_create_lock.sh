# create a lockfile in $NETFS_PREFIX to avoid that mkrescue overwrites ISO/LOGFILE
# made by a previous mkbackup run when the variable NETFS_KEEP_OLD_BACKUP_COPY has been set

# do not do this for tapes and special attention for file:///path
url="$( echo $stage | tr '[:lower:]' '[:upper:]')_URL"
local scheme=$(url_scheme ${!url})
local path=$(url_path ${!url})
local opath=$(backup_path $scheme $path)

# if $opath is empty return silently (e.g. scheme tape)
[ -z "$opath" ] && return 0

if test -d "${opath}" ; then
	> "${opath}/.lockfile"
	StopIfError "Could not create '${opath}/.lockfile'"
fi
