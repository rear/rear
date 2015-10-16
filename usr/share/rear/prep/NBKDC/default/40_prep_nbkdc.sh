#
# prepare stuff for NovaBACKUP DataCenter
#

# detect where and if DataCenter client is installed on the system running
# REAR and include the needed bits in the recovery ISO
if [ -e /Hiback ]; then

        Log "Detected NovaBACKUP DC Installation"
	
	source $SHARE_DIR/lib/nbkdc-functions.sh
	
        # include DataCenter executables and configuration files 
        COPY_AS_IS=( 
                "${COPY_AS_IS[@]}" 
                "${COPY_AS_IS_NBKDC[@]}" 
                $SHARE_DIR 
                $VAR_DIR 
                $NBKDC_DIR/conf
                $NBKDC_DIR/log
				$NBKDC_DIR/rcmd-executor 
                $NBKDC_HIB_DIR 
        )

        # do not include certain DataCenter folders as generated boot
        # image will grow too big if DataCenter listing and temporary
        # files are included
        COPY_AS_IS_EXCLUDE=( 
                "${COPY_AS_IS_EXCLUDE[@]}" 
                "${COPY_AS_IS_EXCLUDE_NBKDC[@]}" 
                $NBKDC_DIR/log/*.*
                $NBKDC_HIBTMP_DIR 
                $NBKDC_HIBLIS_DIR 
                $NBKDC_HIBTPD_DIR/*.tpd
				$NBKDC_HIB_DIR/ora* 
				$NBKDC_HIB_DIR/ndmp 
				$NBKDC_HIB_DIR/mm 
				$NBKDC_HIB_DIR/hui 
				$NBKDC_HIB_DIR/stp
				$NBKDC_HIB_DIR/svn
				$NBKDC_HIB_DIR/vmgr
				$NBKDC_HIB_DIR/svm 
        )


fi
