
# restore/DP/default/460_press_y_to_continue.sh

unset REPLY
while true ; do
    # Use the original STDIN STDOUT and STDERR when 'rear' was launched by the user
    # because 'read' outputs non-error stuff also to STDERR (e.g. its prompt):
    read -t $WAIT_SECS -r -n 1 -p "Press 'y' to continue or wait for $WAIT_SECS seconds timeout: " 0<&6 1>&7 2>&8
    rc=$?
    # In case of timeout 'read -t' results exit code 142 = 128 + 14 (14 is SIGALRM timer signal from alarm(2)):
    (( $rc == 142 )) && break
    (( $rc == 1 )) && break
    case $REPLY in
        (y|Y) break ;;
        (*)   continue ;;
    esac
done
UserOutput ""

