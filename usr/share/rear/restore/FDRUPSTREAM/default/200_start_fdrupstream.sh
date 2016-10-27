#
# Start FDRUPSTREAM
#

echo
LogPrint "Starting FDR/Upstream..."
echo

$FDRUPSTREAM_INSTALL_PATH/fdrupstream start
StopIfError "Error starting FDR/Upstream.  Cannot proceed."
