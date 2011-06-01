# check ISO_DIR directory
[ -d "${ISO_DIR}" ]
StopIfError $? "The ISO output directory '${ISO_DIR}' does not exit"
