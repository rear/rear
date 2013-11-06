# start included sesam client so file restore can happen:

if [ -e /etc/sesam2000.ini ]; then
        SM_INI=`grep SM_INI /etc/sesam2000.ini | cut -d '=' -f 2`

        SESAM_VAR_DIR=`grep ^gv_rw= $SM_INI | cut -d '=' -f 2`
        SESAM_WORK_DIR=`grep ^gv_rw_work= $SM_INI | cut -d '=' -f 2`

        # create sesam Semaphore directory
        mkdir -p $SESAM_WORK_DIR/sem/

        # start sesam client via included init script
        /etc/init.d/sesam start
fi
