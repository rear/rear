# mkdist-workflow.sh
#
#
# create RPM files of rear
#

if [[ "$VERBOSE" ]]; then
    WORKFLOW_mkrpm_DESCRIPTION="create rpm packages using installed rear"
fi
WORKFLOWS=( ${WORKFLOWS[@]} mkrpm )
WORKFLOW_mkrpm () {

	has_binary rpmbuild
	StopIfError "Please install 'rpmbuild' into your PATH."

	# create dist archives
	WORKFLOW_mkdist

	LogPrint "Creating RPM packages "

	rpmbuild -ta $v "$distarchive" 2>&1 | tee -a /dev/fd/8 /dev/fd/2 | grep '\.rpm$' >$TMP_DIR/rpmbuild
	[ $PIPESTATUS -eq 0 ]
	StopIfError "Could not build RPM. See '$LOGFILE' for more information."

	LogPrint "$(cat $TMP_DIR/rpmbuild)"
}
