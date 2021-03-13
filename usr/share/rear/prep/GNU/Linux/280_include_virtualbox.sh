# Pick up virtualbox modules and tools.
if lsmod | grep -q vbox ; then
    # virtualbox modules (if present)
    VBOX_MODULES=( vboxsf vboxvideo vboxguest )
    MODULES+=( ${VBOX_MODULES[@]} )
    CLONE_USERS+=( vboxadd )
    CLONE_GROUPS+=( vboxusers )
    # As libX* seems to be required by VBoxClient - however, no idea if we really needs this at all
    # see issue #1474 for background information
    #VBOX_COPY_AS_IS=( /etc/init.d/vboxadd* /opt/VBoxGuestAdditions-* /usr/sbin/VBoxService )
    VBOX_COPY_AS_IS=( /etc/init.d/vboxadd*  /usr/sbin/VBoxService )
    COPY_AS_IS+=( ${VBOX_COPY_AS_IS[@]} )
    Log "Adding virtualbox modules"
fi
