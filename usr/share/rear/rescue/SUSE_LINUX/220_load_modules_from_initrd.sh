if test -s /etc/sysconfig/kernel ; then
    MODULES_LOAD=( "${MODULES_LOAD[@]}"
      $(
        INITRD_MODULES=
        source /etc/sysconfig/kernel
        echo $INITRD_MODULES
      )
    )
fi
: # set 0 as return value
