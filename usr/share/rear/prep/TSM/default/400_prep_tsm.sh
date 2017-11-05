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

# Need to export LD_LIBRARY_PATH in order for chrooted ldd to find TSM libraries during check in build/default/980_verify_rootfs.sh
# see https://github.com/rear/rear/issues/1533
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/tivoli/tsm/client/ba/bin:/opt/tivoli/tsm/client/api/bin64:/opt/tivoli/tsm/client/api/bin:/opt/tivoli/tsm/client/api/bin64/cit/bin
