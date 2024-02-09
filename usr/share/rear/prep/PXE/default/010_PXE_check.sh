# Ensure that PXE settings have sane values

if [[ "$PXE_TFTP_URL" ]] ; then
    if [[ "$PXE_TFTP_UPLOAD_URL" ]] ; then
        if [[ "$PXE_TFTP_URL" = "$PXE_TFTP_UPLOAD_URL" ]] ; then
	    LogPrintError "-----------------------------------------------------------"
	    LogPrintError "Configuration warning:"
	    LogPrintError "PXE_TFTP_URL and PXE_TFTP_UPLOAD_URL have the same value."
	    LogPrintError "PXE_TFTP_URL is deprecated/replaced by PXE_TFTP_UPLOAD_URL."
	    LogPrintError "Please fix your configuration."
	    LogPrintError "-----------------------------------------------------------"
	else
	    Error "Configuration error: PXE_TFTP_URL and PXE_TFTP_UPLOAD_URL have different values. PXE_TFTP_URL is deprecated/replaced by PXE_TFTP_UPLOAD_URL. Please fix your configuration"
	fi
    else
	LogPrintError "-------------------------------------------------------------------------"
        LogPrintError "Configuration warning:"
	LogPrintError "PXE_TFTP_URL is set and PXE_TFTP_UPLOAD_URL is not set."
	LogPrintError "PXE_TFTP_URL is deprecated/replaced by PXE_TFTP_UPLOAD_URL."
	LogPrintError "Setting PXE_TFTP_UPLOAD_URL to the value of PXE_TFTP_URL and continuing."
	LogPrintError "Please fix your configuration."
	LogPrintError "-------------------------------------------------------------------------"
	PXE_TFTP_UPLOAD_URL="$PXE_TFTP_URL"
    fi
fi

if [[ "$PXE_HTTP_URL" ]] ; then
    if [[ "$PXE_HTTP_DOWNLOAD_URL" ]] ; then
        if [[ "$PXE_HTTP_URL" = "$PXE_HTTP_DOWNLOAD_URL" ]] ; then
	    LogPrintError "-----------------------------------------------------------"
	    LogPrintError "Configuration warning:"
	    LogPrintError "PXE_HTTP_URL and PXE_HTTP_DOWNLOAD_URL have the same value."
	    LogPrintError "PXE_HTTP_URL is deprecated/replaced by PXE_HTTP_DOWNLOAD_URL."
	    LogPrintError "Please fix your configuration."
	    LogPrintError "-----------------------------------------------------------"
	else
	    Error "Configuration error: PXE_HTTP_URL and PXE_HTTP_DOWNLOAD_URL have different values. PXE_HTTP_URL is deprecated/replaced by PXE_HTTP_DOWNLOAD_URL. Please fix your configuration"
	fi
    else
	LogPrintError "-------------------------------------------------------------------------"
        LogPrintError "Configuration warning:"
	LogPrintError "PXE_HTTP_URL is set and PXE_HTTP_DOWNLOAD_URL is not set."
	LogPrintError "PXE_HTTP_URL is deprecated/replaced by PXE_HTTP_DOWNLOAD_URL."
	LogPrintError "Setting PXE_HTTP_DOWNLOAD_URL to the value of PXE_HTTP_URL and continuing."
	LogPrintError "Please fix your configuration."
	LogPrintError "-------------------------------------------------------------------------"
	PXE_HTTP_DOWNLOAD_URL="$PXE_HTTP_URL"
    fi
fi

if [[ "$PXE_HTTP_DOWNLOAD_URL" ]] ; then
    if [[ -z "$PXE_HTTP_UPLOAD_URL" ]] ; then
	LogPrintError "----------------------------------------------------------------------------"
        LogPrintError "Configuration warning:"
	LogPrintError "PXE_HTTP_DOWNLOAD_URL is set and PXE_HTTP_UPLOAD_URL is not set."
	LogPrintError "This probably means that later you will try to download something"
	LogPrintError "that never got uploaded."
	LogPrintError 'If you know what you are doing set PXE_HTTP_UPLOAD_URL="$PXE_TFTP_UPLOAD_URL"'
	LogPrintError "to get rid of this warning."
	LogPrintError "----------------------------------------------------------------------------"
    fi
fi
