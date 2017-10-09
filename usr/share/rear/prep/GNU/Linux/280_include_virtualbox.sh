# Pick up virtualbox modules and tools.
if lsmod | grep -q vbox ; then
    # virtualbox modules (if present)
    VBOX_MODULES=( vboxsf vboxvideo vboxguest )
    MODULES=( ${MODULES[@]} ${VBOX_MODULES[@]} )
    CLONE_USERS=( ${CLONE_USERS[@]}  vboxadd )
    CLONE_GROUPS=( ${CLONE_GROUPS[@]} vboxusers )
    VBOX_COPY_AS_IS=( /etc/init.d/vboxadd* /opt/VBoxGuestAdditions-* /usr/sbin/VBoxService )
    COPY_AS_IS=( ${COPY_AS_IS[@]} ${VBOX_COPY_AS_IS[@]} )
    Log "Adding virtualbox modules"
fi
