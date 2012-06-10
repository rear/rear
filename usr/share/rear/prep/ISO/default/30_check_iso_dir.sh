### Check ISO_DIR directory
if [[ ! -d "$ISO_DIR" ]]; then
    mkdir $v -p -m0755 "$ISO_DIR"
    StopIfError "The ISO output directory '$ISO_DIR' cannot be created."
fi
