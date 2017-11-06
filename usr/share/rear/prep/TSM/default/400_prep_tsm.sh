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
