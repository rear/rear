# Ensure that PXE settings have sane values

if [[ "$PXE_TFTP_URL" ]] ; then
    if [[ "$PXE_TFTP_UPLOAD_URL" ]] ; then
        if [[ "$PXE_TFTP_URL" = "$PXE_TFTP_UPLOAD_URL" ]] ; then
            LogPrintError "----------------------------------------------------"
            LogPrintError "Configuration warning:"
            LogPrintError "PXE_TFTP_URL and PXE_TFTP_UPLOAD_URL are same."
            LogPrintError "PXE_TFTP_URL is deprecated. Use PXE_TFTP_UPLOAD_URL."
            LogPrintError "----------------------------------------------------"
        else
            Error "PXE_TFTP_URL and PXE_TFTP_UPLOAD_URL differ. PXE_TFTP_URL is deprecated. Use PXE_TFTP_UPLOAD_URL."
        fi
    else
        LogPrintError "---------------------------------------------------------"
        LogPrintError "Configuration warning:"
        LogPrintError "PXE_TFTP_URL is set and PXE_TFTP_UPLOAD_URL is not set."
        LogPrintError "PXE_TFTP_URL is deprecated. Use PXE_TFTP_UPLOAD_URL."
        LogPrintError "Using PXE_TFTP_UPLOAD_URL with the value of PXE_TFTP_URL."
        LogPrintError "---------------------------------------------------------"
        PXE_TFTP_UPLOAD_URL="$PXE_TFTP_URL"
    fi
fi

if [[ "$PXE_HTTP_URL" ]] ; then
    if [[ "$PXE_HTTP_DOWNLOAD_URL" ]] ; then
        if [[ "$PXE_HTTP_URL" = "$PXE_HTTP_DOWNLOAD_URL" ]] ; then
            LogPrintError "------------------------------------------------------"
            LogPrintError "Configuration warning:"
            LogPrintError "PXE_HTTP_URL and PXE_HTTP_DOWNLOAD_URL are same."
            LogPrintError "PXE_HTTP_URL is deprecated. Use PXE_HTTP_DOWNLOAD_URL."
            LogPrintError "------------------------------------------------------"
        else
            Error "PXE_HTTP_URL and PXE_HTTP_DOWNLOAD_URL differ. PXE_HTTP_URL is deprecated. Use PXE_HTTP_DOWNLOAD_URL."
        fi
    else
        LogPrintError "-----------------------------------------------------------"
        LogPrintError "Configuration warning:"
        LogPrintError "PXE_HTTP_URL is set and PXE_HTTP_DOWNLOAD_URL is not set."
        LogPrintError "PXE_HTTP_URL is deprecated. Use PXE_HTTP_DOWNLOAD_URL."
        LogPrintError "Using PXE_HTTP_DOWNLOAD_URL with the value of PXE_HTTP_URL."
        LogPrintError "-----------------------------------------------------------"
        PXE_HTTP_DOWNLOAD_URL="$PXE_HTTP_URL"
    fi
fi

if [[ "$PXE_HTTP_DOWNLOAD_URL" ]] ; then
    if [[ -z "$PXE_HTTP_UPLOAD_URL" ]] ; then
        LogPrintError "----------------------------------------------------------------"
        LogPrintError "Configuration warning:"
        LogPrintError "PXE_HTTP_DOWNLOAD_URL is set but PXE_HTTP_UPLOAD_URL is not set."
        LogPrintError "Also set PXE_HTTP_UPLOAD_URL to make HTTP download work."
        LogPrintError "----------------------------------------------------------------"
    fi
fi
