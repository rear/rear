# mkdist-workflow.sh
#
#
# create RPM files of rear
#

WORKFLOW_mkrpm_DESCRIPTION="Create RPM packages with this rear version"
WORKFLOWS=( ${WORKFLOWS[@]} mkrpm )
WORKFLOW_mkrpm () {

	type -p rpmbuild >/dev/null
	StopIfError "Please install 'rpmbuild' into your PATH."

	# create dist archives
	WORKFLOW_mkdist

	LogPrint "Creating RPM packages "
	
	rpmbuild -ta -v "$distarchive" 2>&1 | tee -a /dev/fd/8 /dev/fd/2 | grep '\.rpm$' >$TMP_DIR/rpmbuild
	[ $PIPESTATUS -eq 0 ]
	StopIfError "Could not build RPM. See '$LOGFILE' for more information."

	LogPrint "$(cat $TMP_DIR/rpmbuild)"
}
