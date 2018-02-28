#
# prepare stuff for TSM
#

# some sites have strange habits ... (dms.* files not where they should be)

COPY_AS_IS=( "${COPY_AS_IS[@]}" "${COPY_AS_IS_TSM[@]}"
	$(readlink /opt/tivoli/tsm/client/ba/bin/dsm.sys)
	$(readlink /opt/tivoli/tsm/client/ba/bin/dsm.opt)
	)
COPY_AS_IS_EXCLUDE=( "${COPY_AS_IS_EXCLUDE[@]}" "${COPY_AS_IS_EXCLUDE_TSM[@]}" )
PROGS=( "${PROGS[@]}" "${PROGS_TSM[@]}" )

# Find gsk lib diriectory and add it to the TSM_LD_LIBRARY_PATH
# see issue https://github.com/rear/rear/issues/1688
for gsk_dir in $(ls -d /usr/local/ibm/gsk*/lib* ) ; do
	TSM_LD_LIBRARY_PATH=$TSM_LD_LIBRARY_PATH:$gsk_dir
done
