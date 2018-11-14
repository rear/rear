
# 950_check_missing_programs.sh
#
# Check that all required programs exist in the currently running system.
# During "rear mkrescue/mkbackup" the currently running system is the original system
# but during "rear recover" the currently running system is the recovery system.
# Do this check during the 'init' stage because the 'init' stage is always run
# (the 'init' stage is run unconditioned by the usr/sbin/rear main script).
# During "rear mkrescue/mkbackup" the 'prep' and 'layout/save' and 'rescue' stages run after the 'init' stage
# and there additional required programs are added to the REQUIRED_PROGS array
# (e.g. see rescue/GNU/Linux/310_network_devices.sh)
# Therefore this check script is additionally run at the end of the 'build' stage
# (via the symbolic link build/default/950_check_missing_programs.sh -> init/default/950_check_missing_programs.sh)
# cf. https://github.com/rear/rear/issues/892

# Without the empty string as initial value missing_progs ${missing_progs[*]} ${missing_progs[@]}
# would all be unbound variables that would result an error exit if 'set -eu' is used:
missing_progs=( '' )

# Check for required binaries:
for prog in "${REQUIRED_PROGS[@]}" ; do
    has_binary "$prog" || missing_progs=( "${missing_progs[@]}" "$prog" )
done

# Have all array members as a single word like "${arr[*]}" because it should detect
# when there is any non-empty array member (not necessarily the first one) and here
# the first array member is always the empty string because of missing_progs=( '' ) above:
contains_visible_char "${missing_progs[*]}" && Error "Cannot find required programs: ${missing_progs[@]}"

