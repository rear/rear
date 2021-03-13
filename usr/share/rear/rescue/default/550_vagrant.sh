# purpose of this script is copy the user vagrant and its home dir to the rescue image
# only required when working with vagrant of course

if PASSWD_VAGRANT=$(grep vagrant /etc/passwd) ; then
    #vagrant:x:1000:1000:vagrant:/home/vagrant:/bin/bash
    echo "$PASSWD_VAGRANT" >>$ROOTFS_DIR/etc/passwd
    IFS=: read user ex uid gid gecos homedir junk <<<"$PASSWD_VAGRANT"
    CLONE_GROUPS+=( "$gid" admin )
    mkdir -p $v -m 0700 "$ROOTFS_DIR$homedir"
    chown $v ${user}:${gid} "$ROOTFS_DIR$homedir"
    COPY_AS_IS+=( $homedir/.s[s]h ) 
    # grab the shadow entry - if hashed use that one otherwise generate genric entry with password vagrant
    IFS=: read user hash junk <<<$(grep $user /etc/shadow)
    case "$hash" in
       '$1$'*) echo "$user:$hash:$junk" >> $ROOTFS_DIR/etc/shadow ;;
       *     ) echo "$user:$(echo vagrant | openssl passwd -1 -stdin):::::::" >> $ROOTFS_DIR/etc/shadow ;;
    esac
    Log "Vagrant user created including home directory on rescue image"

fi
