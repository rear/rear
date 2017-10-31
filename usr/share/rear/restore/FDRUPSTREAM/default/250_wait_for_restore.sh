#
# Pause for FDRUPSTREAM restore
#

LogUserOutput "
   Perform your restore using Director or by submitting a batch job.

   IMPORTANT: Restore the entire '/' filesystem to '$TARGET_FS_ROOT'
   on the recovery system.
   When the restore is complete, then hit <enter> here.
"
# Use the original STDIN STDOUT and STDERR when 'rear' was launched by the user
# because 'read' outputs non-error stuff also to STDERR (e.g. its prompt):
read 0<&6 1>&7 2>&8

