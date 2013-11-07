# start included sesam client so file restore can happen:
if [ -e /etc/sesam2000.ini ]; then

        # get sesam installation
        source $SHARE_DIR/lib/sesam-functions.sh
        # set the sesam environment profile
        source $SESAM_VAR_DIR/var/ini/sesam2000.profile

        # create sesam Semaphore directory
        mkdir -p $SESAM_WORK_DIR/sem/

        # start sesam client daemon
        $SESAM_BIN_DIR/bin/sesam/sm_main start
fi
