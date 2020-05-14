
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

local prog
local missing_progs=()

# Check for required binaries:
for prog in "${REQUIRED_PROGS[@]}" ; do
    # When required programs are specified with absolute path like
    # REQUIRED_PROGS+=( /special/path/myprogam )
    # the test "has_binary /special/path/myprogam" works during "rear mkrescue/mkbackup"
    # but that program appears in the ReaR recovery system as /bin/myprogram
    # so "has_binary /special/path/myprogam" fails inside the recovery system
    # which would let "rear recover" falsely error out here
    # cf. https://github.com/rear/rear/issues/2206
    # so we also test "has_binary myprogam" which works inside the recovery system:
    has_binary "$prog" || has_binary "$( basename "$prog" )" || missing_progs+=( "$prog" )
done

# Have all array members as a single word like "${arr[*]}" because it should detect
# when there is any non-empty array member (not necessarily the first one):
contains_visible_char "${missing_progs[*]}" && Error "Cannot find required programs: ${missing_progs[@]}"

# Finish successfully:
return 0
