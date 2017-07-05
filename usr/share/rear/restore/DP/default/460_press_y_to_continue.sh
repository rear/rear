
# FIXME: The 'Left' function only works when STDOUT is an ANSI terminal
# because according to http://ascii-table.com/ansi-escape-sequences.php
# Esc[<number>D moves the cursor back by the specified <number> of columns
# so that strange output happens when STDOUT is not an ANSI terminal:
c_esc="\033"
Left () {
   echo -ne ${c_esc}[${1}D
}

unset REPLY
# Use the original STDOUT when 'rear' was launched by the user for the 'echo' output
# and for the 'Left' output in the 'while' loop
# but keep STDERR going to the log file so that 'rear -D' output goes to the log file:
echo -ne "Press \"y\" to continue or wait for timeout [30 secs]: " 1>&7
while true
do
    # Use the original STDIN STDOUT and STDERR when 'rear' was launched by the user
    # because 'read' outputs non-error stuff also to STDERR (e.g. its prompt):
    read -t $WAIT_SECS -r -n 1 0<&6 1>&7 2>&8
    rc=$?
    (( $rc == 142 )) && break
    (( $rc == 1 )) && break
    case $REPLY in
        y|Y) break ;;
        *) Left 1 ; continue ;;
    esac
done 1>&7
UserOutput ""

