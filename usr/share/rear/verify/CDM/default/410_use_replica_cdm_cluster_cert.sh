# 410_use_replica_cdm_cluster_cert.sh
# If restoring from a replica Rubrik (CDM) cluster use it's cert for RBS.

CDM_RBA_DIR=/etc/rubrik
CDM_KEYS_DIR=${CDM_RBA_DIR}/keys

# When USER_INPUT_CDM_REPLICA_CLUSTER has any 'true' value be liberal in what you accept and assume exactly 'y' was actually meant:
LogPrint ""
is_true "$USER_INPUT_CDM_REPLICA_CLUSTER" && USER_INPUT_CDM_REPLICA_CLUSTER="y"
while true ; do
    # Find out if the restore is being done from the original CDM cluster or a Replica
    # the default (i.e. the automated response after the timeout) should be 'n':
    answer="$( UserInput -I CDM_REPLICA_CLUSTER -p "Is the data being restored from the original CDM Cluster? (y/n)" -D 'y' -t 300 )"
    is_true "$answer" && return 0
    if is_false "$answer" ; then
        break
    fi
    UserOutput "Please answer 'y' or 'n'"
done

while true ; do
    CDM_CLUSTER_IP="$(UserInput -I USER_INPUT_CDM_CLUSTER_IP -r -t 0 -p "Enter one of the IP addresses for the replica CDM cluster: ")"
    [[ -n "$CDM_CLUSTER_IP" ]] && break
    PrintError "Please enter a non-empty CDM cluster IP."
done

# The name of the tar file that is being downloaded has changed in Rubrik CDM v5.1.
# Before Rubrik CDM v5.1 it was rubrik-agent-sunos5.10.sparc.tar.gz
# since Rubrik CDM v5.1 it is rubrik-agent-solaris.sparc.tar.gz
# cf. https://github.com/rear/rear/issues/2441

CDM_SUNOS_TAR=rubrik-agent-sunos5.10.sparc.tar.gz
CDM_SOLARIS_TAR=rubrik-agent-solaris.sparc.tar.gz
CDM_TAR_FILE=$CDM_SUNOS_TAR
# FIXME: 'cd /tmp' changes the working directory hardcoded to /tmp but why not to $TMPDIR ?
# cf. https://github.com/rear/rear/pull/2445/files#r448155637
# Additionally I <jsmeix@suse.de> am missing the counterpart that changes the working directory
# back to what it was before, i.e. via 'pushd $TMPDIR' plus 'popd' at the end of the script
# e.g. as in output/ISO/Linux-ppc64le/820_create_iso_image.sh
# (careful in case of 'return' after 'pushd': must call the matching 'popd' before 'return'):
cd /tmp
if ! curl $v -fskLOJ https://${CDM_CLUSTER_IP}/connector/${CDM_TAR_FILE} ; then
    CDM_TAR_FILE=$CDM_SOLARIS_TAR
    if ! curl $v -fkLOJ https://${CDM_CLUSTER_IP}/connector/${CDM_TAR_FILE} ; then
        Error "Could not download Rubrik agent from https://${CDM_CLUSTER_IP}/connector/${CDM_SUNOS_TAR} or https://${CDM_CLUSTER_IP}/connector/${CDM_SOLARIS_TAR}."
    fi
fi

tar $v -xzf  $CDM_TAR_FILE || Error "Could not extract $CDM_TAR_FILE"

CDM_CERT_FILE=$(find ./ -name "rubrik.crt")
mv $v ${CDM_KEYS_DIR}/rubrik.crt ${CDM_KEYS_DIR}/rubrik.crt.orig
cp $v $CDM_CERT_FILE $CDM_KEYS_DIR || Error "Could not copy replica CDM cluster certificate"

chmod $v 600 ${CDM_KEYS_DIR}/rubrik.crt

mv $v ${CDM_KEYS_DIR}/agent.crt ${CDM_KEYS_DIR}/agent.crt.orig
mv $v ${CDM_KEYS_DIR}/agent.pem ${CDM_KEYS_DIR}/agent.pem.orig
/etc/rubrik/rba-keygen.sh

LogPrint "Replica Rubrik (CDM) cluster certificate installed."
