# report to user what we did
USB_SIZE=( $( du -shc "${USB_FILES[@]}" | tail -n 1 ) )
LogPrint "Please put the following files ($USB_SIZE) onto your prepared USB stick
${USB_FILES[@]}"

# Add to RESULT_FILES for emailing it
RESULT_FILES=( "${RESULT_FILES[@]}" "${USB_FILES[@]}" )
