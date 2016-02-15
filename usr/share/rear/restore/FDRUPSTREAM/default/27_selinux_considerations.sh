#
# Optionally relabel an SELinux-protected system
#

# ---- Is this a standard path for the selinux config file?
if [ $( grep "SELINUX=enforcing" $TARGET_FS_ROOT/etc/selinux/config ) ]; then
# ----
    echo
    echo "SELinux is currently set to enforcing mode."
    echo "Relabeling of the root filesystem may be required"
    echo "in order to allow login of the restored system."
    while true; do
        echo
        echo "Would you like to relabel on next boot? (y/n)"
        read ANSWER
        case $ANSWER in
            [Yy] ) touch $TARGET_FS_ROOT/.autorelabel; break;;
            [Nn] ) break;;
            * ) echo; echo "Please answer 'y' or 'n'";;
        esac
    done
fi
