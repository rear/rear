# mkdist-workflow.sh
#
#
# create distribution files of rear
#

if [[ "$VERBOSE" ]]; then
    WORKFLOW_mkvendorrpm_DESCRIPTION="create vendor rpm package using installed rear"
fi
WORKFLOWS=( ${WORKFLOWS[@]} mkvendorrpm )
WORKFLOW_mkvendorrpm () {

	WORKFLOW_mkdist

	LogPrint "Building vendor RPMs"

	RPM_TopDir=`rpmtopdir`	# find rpmbuild %{_topdir} path
	cp -fp $v $SHARE_DIR/lib/rear.spec ${RPM_TopDir}/SPECS/rear.spec >&2
	StopIfError "Could not copy ${RPM_TopDir}/SPECS/rear.spec"

	chmod $v 644 ${RPM_TopDir}/SPECS/rear.spec >&2
	cp -fp $v $distarchive ${RPM_TopDir}/SOURCES/ >&2
	StopIfError "Could not copy $distarchive to ${RPM_TopDir}/SOURCES/"

	rpmbuild -ba $v ${RPM_TopDir}/SPECS/rear.spec 2>&1 | tee -a /dev/fd/8 /dev/fd/2 | grep '\.rpm$' >$TMP_DIR/rpmbuild 
	[ $PIPESTATUS -eq 0 ]
	StopIfError $PIPESTATUS "Could not build RPM. See '$LOGFILE' for more information."

	LogPrint "$(cat $TMP_DIR/rpmbuild)"
				
}
