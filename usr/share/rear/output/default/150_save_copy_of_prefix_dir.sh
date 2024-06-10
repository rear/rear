# if KEEP_OLD_OUTPUT_COPY is not empty then move old OUTPUT_PREFIX directory to OUTPUT_PREFIX.old

[ -z "${KEEP_OLD_OUTPUT_COPY}" ] && return

# do not do this for tapes and special attention for file:///path
local scheme="$( url_scheme "$OUTPUT_URL" )"
local path="$( url_path "$OUTPUT_URL" )"

# if filesystem access to url is unsupported return silently (e.g. scheme tape)
scheme_supports_filesystem $scheme || return 0

local opath="$( output_path "$scheme" "$path" )"

# an old lockfile from a previous run not cleaned up by output is possible
[[ -f "${opath}/.lockfile" ]] && rm -f "${opath}/.lockfile" >&2

if test -d "${opath}" ; then
    rm -rf $v "${opath}.old" || Error "Could not remove '${opath}.old'"
    # below statement was 'cp -af' instead of 'mv -f' (see issue #192)
    mv -f $v "${opath}" "${opath}.old" || Error "Could not move '${opath}'"
fi
# the ${BUILD_DIR}/outputfs/${OUTPUT_PREFIX} will be created by output/default/200_make_prefix_dir.sh
