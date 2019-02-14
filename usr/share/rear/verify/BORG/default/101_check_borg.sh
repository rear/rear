Log "Checking Borg binary"

# Do we have Borg binary?
has_binary borg
StopIfError "Could not find Borg binary"
