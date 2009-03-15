# check ISO_DIR directory
test -d "${ISO_DIR}" 
ProgressStopIfError $? "The ISO output directory '${ISO_DIR}' does not exit"
ProgressStep
