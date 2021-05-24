# if KEEP_OLD_OUTPUT_COPY is not empty then move old OUTPUT_PREFIX directory to OUTPUT_PREFIX.old

[ -z "${KEEP_OLD_OUTPUT_COPY}" ] && return

# do not do this for tapes and special attention for file:///path
url="$( echo $stage | tr '[:lower:]' '[:upper:]' )_URL"
local scheme=$( url_scheme ${!url} )
local path=$( url_path ${!url} )
local opath=$( output_path $scheme $path )

# if $opath is empty return silently (e.g. scheme tape)
[ -z "$opath" ] && return 0

# an old lockfile from a previous run not cleaned up by output is possible
[[ -f ${opath}/.lockfile ]] && rm -f ${opath}/.lockfile >&2

if test -d "${opath}" ; then
    rm -rf $v "${opath}.old" >&2
    StopIfError "Could not remove '${opath}.old'"
    # below statement was 'cp -af' instead of 'mv -f' (see issue #192)
    mv -f $v "${opath}" "${opath}.old" >&2
    StopIfError "Could not move '${opath}'"
fi
# the ${BUILD_DIR}/outputfs/${OUTPUT_PREFIX} will be created by output/default/200_make_prefix_dir.sh
