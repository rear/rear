#
# adapt some ssh configs

# Patch sshd_config:
# - disable password authentication because rescue system does not have PAM etc.
# - disable challange response (Kerberos, skey, ...) for same reason
# - disable PAM
# - disable motd printing, our /etc/profile does that
# The idea is to allow only ssh authorized_keys based access which HAS TO BE ENABLED
# also in the original system to work here as we DO NOT ENABLE IT FOR YOU !

# important for the [n] hack below because we want non-existant patterns to simply disappear
shopt -s nullglob
SSH_CONFIG_FILES=( $ROOTFS_DIR/etc/ssh/sshd_co[n]fig $ROOTFS_DIR/etc/sshd_co[n]fig $ROOTFS_DIR/etc/openssh/sshd_co[n]fig)
if test "$SSH_CONFIG_FILES" ; then
sed -i  -e 's/ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/ig' \
	-e 's/UsePAM.*/UsePam no/ig' \
	-e 's/ListenAddress.*/ListenAddress 0.0.0.0/ig' \
	-e '1i PrintMotd no' \
	$ROOTFS_DIR/etc/sshd_co[n]fig $ROOTFS_DIR/etc/ssh/sshd_co[n]fig $ROOTFS_DIR/etc/openssh/sshd_co[n]fig
	
	if [ -n "$SSH_ROOT_PASSWORD" ] ; then 
		sed -i -e 's/PasswordAuthentication.*/PasswordAuthentication yes/ig' $ROOTFS_DIR/etc/sshd_co[n]fig $ROOTFS_DIR/etc/ssh/sshd_co[n]fig $ROOTFS_DIR/etc/openssh/sshd_co[n]fig
	else
		sed -i  -e 's/PasswordAuthentication.*/PasswordAuthentication no/ig' $ROOTFS_DIR/etc/sshd_co[n]fig $ROOTFS_DIR/etc/ssh/sshd_co[n]fig $ROOTFS_DIR/etc/openssh/sshd_co[n]fig
	fi
else
	Log "WARNING: ssh configuration files missing"
fi

