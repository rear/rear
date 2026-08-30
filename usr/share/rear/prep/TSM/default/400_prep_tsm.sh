#
# prepare stuff for TSM
#

# some sites have strange habits ... (dsm.* files not where they should be)
# FIXME: Clearly explain what plain 'readlink' is meant to do here,
# cf. "Code must be easy to understand (answer the WHY)"
# in https://github.com/rear/rear/wiki/Coding-Style
# Plain 'readlink' means "readlink mode" where 'readlink' produces no output
# when its argument is not the name of a symbolic link so for regular files
# like "readlink /etc/fstab" produces no output (and results exit code 1).
# So e.g. "readlink /opt/tivoli/tsm/client/ba/bin/dsm.sys" only produces output
# when /opt/tivoli/tsm/client/ba/bin/dsm.sys is no regular file but a symbolic link.
# It seems the only possible way how dsm.* files could be not where they should be
# is that the expected dsm.* regular file path was replaced by a symbolic link.
# But when the value of a symbolic link is not an absolute path
# then plain 'readlink' does not resolve a relative path
# e.g. for the symbolic link /etc/issue -> ../run/issue
# plain 'readlink' outputs "../run/issue" which will get resolved relative
# to the current working directory of the code which evaluates COPY_AS_IS
# i.e. the working directory of build/GNU/Linux/100_copy_as_is.sh
# which is WORKING_DIR (see the Source function) that is set in sbin/rear
# to the current working directory when sbin/rear was launched.
# So this likely fails when a dsm.* file symlink value is a relative path.
COPY_AS_IS+=( "${COPY_AS_IS_TSM[@]}"
              $( readlink /opt/tivoli/tsm/client/ba/bin/dsm.sys )
              $( readlink /opt/tivoli/tsm/client/ba/bin/dsm.opt )
            )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_TSM[@]}" )
PROGS+=( "${PROGS_TSM[@]}" )

# The usual TSM_DSMC_OPTFILE location should be in /opt/tivoli/tsm/client/ba/bin/
# which gets included via the default COPY_AS_IS_TSM=( ... /opt/tivoli/tsm/client ... )
# but it can be anywhere ('readlink -e' because COPY_AS_IS does not not follow symlinks):
test "$TSM_DSMC_OPTFILE" && COPY_AS_IS+=( $( readlink -e "$TSM_DSMC_OPTFILE" ) )

# Find gsk lib diriectory and add it to the TSM_LD_LIBRARY_PATH
# see issue https://github.com/rear/rear/issues/1688
for gsk_dir in $(ls -d /usr/local/ibm/gsk*/lib* ) ; do
	TSM_LD_LIBRARY_PATH=$TSM_LD_LIBRARY_PATH:$gsk_dir
done

# Use a TSM-specific LD_LIBRARY_PATH to find TSM libraries
# see https://github.com/rear/rear/issues/1533
LD_LIBRARY_PATH_FOR_BACKUP_TOOL="$TSM_LD_LIBRARY_PATH"
