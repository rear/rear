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

        # do not include certain sesam folders content as generated boot
        # image will grow too big if sesam listing, temporary, working and log
        # files are included (don't also exclude the directories themselves
        # as they're required for the sesam client to work in the recovery
        # environment); double-quoting is required to prevent the shell from
        # expanding those entries already here, which does not include e.g.
        # hidden files/dirs like /var/opt/sesam/var/tmp/.guestfs-0/ - if tar
        # is given such an exclude it does it right ...
        COPY_AS_IS_EXCLUDE+=(
            "${COPY_AS_IS_EXCLUDE_SESAM[@]}" 
            "${SESAM_WORK_DIR}/*"
            "${SESAM_TMP_DIR}/*"
            "${SESAM_LIS_DIR}/*"
            "${SESAM_LGC_DIR}/*"
            "${SESAM_SMS_DIR}/*"
            "${SESAM_PROT_DIR}/*"
        )

        # include libssl as it is needed to run sesam sm_sshd if included
        LIBS+=( /usr/lib*/libssl.so.* /usr/lib*/libcrypto.so.* )
fi

# Use a SEP sesam-specific LD_LIBRARY_PATH to find sesam client related libraries
# see https://github.com/rear/rear/pull/1817
LD_LIBRARY_PATH_FOR_BACKUP_TOOL="$SESAM_LD_LIBRARY_PATH"
