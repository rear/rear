#
# prepare stuff for SEP Sesam
#

# detect where and if SEP Sesam client is installed on the system running
# REAR, include the needed bits in the recovery ISO
if [ -e /etc/sesam2000.ini ]; then

        Log "Detected Sesam Installation"

        SM_INI=`grep SM_INI /etc/sesam2000.ini | cut -d '=' -f 2`
        SESAM_BIN_DIR=`grep ^gv_ro= $SM_INI | cut -d '=' -f 2`
        SESAM_VAR_DIR=`grep ^gv_rw= $SM_INI | cut -d '=' -f 2`
        SESAM_WORK_DIR=`grep ^gv_rw_work= $SM_INI | cut -d '=' -f 2`
        SESAM_TMP_DIR=`grep ^gv_rw_tmp= $SM_INI | cut -d '=' -f 2`
        SESAM_LIS_DIR=`grep ^gv_rw_lis= $SM_INI | cut -d '=' -f 2`
        SESAM_LGC_DIR=`grep ^gv_rw_lgc= $SM_INI | cut -d '=' -f 2`
        SESAM_WORK_DIR=`grep ^gv_rw_work= $SM_INI | cut -d '=' -f 2`
        SESAM_SMS_DIR=`grep ^gv_rw_stpd= $SM_INI | cut -d '=' -f 2`
        SESAM_PROT_DIR=`grep ^gv_rw_prot= $SM_INI | cut -d '=' -f 2`

        # include sesam executables and configuration files 
        # also includes some more tools to ensure init script
        # functionality
        COPY_AS_IS=( 
                "${COPY_AS_IS[@]}" 
                "${COPY_AS_IS_SESAM[@]}" 
                $SHARE_DIR 
                $VAR_DIR 
                $SESAM_BIN_DIR 
                $SESAM_VAR_DIR 
                /etc/sesam2000.ini 
                /etc/init.d/functions 
                /etc/init.d/sesam 
                /etc/rc.status 
                /usr/bin/nohup 
                /usr/bin/lsb_release 
                /sbin/consoletype
        )

        # do not include certain sesam folders as generated boot
        # image will grow too big if sesam listing and temporary
        # files are included
        COPY_AS_IS_EXCLUDE=( 
                "${COPY_AS_IS_EXCLUDE[@]}" 
                "${COPY_AS_IS_EXCLUDE_SESAM[@]}" 
                $SESAM_WORK_DIR 
                $SESAM_TMP_DIR 
                $SESAM_LIS_DIR 
                $SESAM_LGC_DIR 
                $SESAM_PROT_DIR 
        )

        PROGS=( "${PROGS[@]}" "${PROGS_SESAM[@]}" )

        # include libssl as it is needed to run sesam sm_sshd if included
        LIBS=( 
            "${LIBS[@]}"
            /usr/lib*/libssl.so.* 
            /usr/lib*/libcrypto.so.* 
        )
fi
