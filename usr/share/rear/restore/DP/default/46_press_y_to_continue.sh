c_esc="\033"
Left () {
   echo -ne ${c_esc}[${1}D
}

unset REPLY
echo -ne "Press \"y\" to continue or wait for timeout [30 secs]: "
while true
do
    read -t $WAIT_SECS -r -n 1
    rc=$?
    (( $rc == 142 )) && break
    (( $rc == 1 )) && break
    case $REPLY in
        y|Y) break ;;
        *) Left 1 ; continue ;;
    esac
done
echo
