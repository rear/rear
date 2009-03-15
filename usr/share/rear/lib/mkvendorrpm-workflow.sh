# mkdist-workflow.sh
#
#
# create distribution files of rear
#

WORKFLOW_mkvendorrpm_DESCRIPTION="Create vendor RPM with this rear version"
WORKFLOWS=( ${WORKFLOWS[@]} mkvendorrpm )
WORKFLOW_mkvendorrpm () {

	WORKFLOW_mkdist

	ProgressStart "Building vendor RPMs"
	RPM_TopDir=`rpmtopdir`	# find rpmbuild %{_topdir} path
	cp -fp $SHARE_DIR/lib/rear.spec ${RPM_TopDir}/SPECS/rear.spec
	ProgressStopIfError $? "Could not copy ${RPM_TopDir}/SPECS/rear.spec"
	chmod 644 ${RPM_TopDir}/SPECS/rear.spec
	cp -fp $distarchive ${RPM_TopDir}/SOURCES/
	ProgressStopIfError $? "Could not copy $distarchive to ${RPM_TopDir}/SOURCES/"
	rpmbuild -ba -v ${RPM_TopDir}/SPECS/rear.spec 2>&1 | tee -a /dev/fd/8 /dev/fd/2 | grep '\.rpm$' >$TMP_DIR/rpmbuild 
	ProgressStopOrError $PIPESTATUS "Could not build RPM. See '$LOGFILE' for more information."
	LogPrint "$(cat $TMP_DIR/rpmbuild)"
				
}
