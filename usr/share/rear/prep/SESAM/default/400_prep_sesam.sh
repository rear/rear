#
# prepare stuff for SEP Sesam
#

# detect where and if SEP Sesam client is installed on the system running
# REAR, include the needed bits in the recovery ISO
if [ -e /etc/sesam2000.ini ]; then

        Log "Detected Sesam Installation"

        source $SHARE_DIR/lib/sesam-functions.sh

        # include sesam executables and configuration files 
        COPY_AS_IS+=(
            "${COPY_AS_IS_SESAM[@]}" 
            $SHARE_DIR 
            $VAR_DIR 
            $SESAM_BIN_DIR 
            $SESAM_VAR_DIR 
            /etc/sesam2000.ini
        )

        # do not include certain sesam folders as generated boot
        # image will grow too big if sesam listing and temporary
        # files are included
        COPY_AS_IS_EXCLUDE+=(
            "${COPY_AS_IS_EXCLUDE_SESAM[@]}" 
            $SESAM_WORK_DIR 
            $SESAM_TMP_DIR 
            $SESAM_LIS_DIR 
            $SESAM_LGC_DIR 
            $SESAM_PROT_DIR 
        )

        # include libssl as it is needed to run sesam sm_sshd if included
        LIBS+=( /usr/lib*/libssl.so.* /usr/lib*/libcrypto.so.* )
fi
