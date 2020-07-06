# 500_restore_ssc.sh
# Purpose: Make Secure Socket Communication useable after restoring the client system

SSCPATH=/etc/opt/omni/client/sscertificates
OMNICC=/opt/omni/bin/omnicc

# Only needed for Data Protector 10.x and later with Secure Communication is configured
if test -s /etc/opt/omni/client/ssconfig; then

    cp $v ${SSCPATH}/localhost_cert.pem /mnt/local/${SSCPATH}/localhost_cert.pem || Error "Could not copy localhost_cert.pem"
    cp $v ${SSCPATH}/localhost_key.pem  /mnt/local/${SSCPATH}/localhost_key.pem  || Error "Could not copy localhost_key.pem"

    if test -s /mnt/local/${SSCPATH}/localhost_cert.pem -a -s /mnt/local/${SSCPATH}/localhost_key.pem
	    
        LogPrint "Client certificate properly restored."
	  
    else

        LogPrint "Client certificate not properly restored. A new certificate will be generated now."
        chroot /mnt/local ${OMNICC} -secure_comm -regenerate_cert
	chroot /mnt/local ${OMNICC} -secure_comm -get_fingerprint
        LogPrint "Run omnicc -secure_comm -configure_peer <Client> on the Cell Manager after rebooting the client system"

fi
