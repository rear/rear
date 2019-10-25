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

while true; do
    CDM_CLUSTER_IP="$(UserInput -I USER_INPUT_CDM_CLUSTER_IP -r -t 0 -p "Enter one of the IP addresses for the replica CDM cluster: ")"
    [[ -n "$CDM_CLUSTER_IP" ]] && break
    PrintError "Please enter a non-empty CDM cluster IP."
done

CDM_SUNOS_TAR=rubrik-agent-sunos5.10.sparc.tar.gz
cd /tmp
/usr/bin/curl $v -kLOJ https://${CDM_CLUSTER_IP}/connector/${CDM_SUNOS_TAR} 
StopIfError "Could not download https://${CDM_CLUSTER_IP}/connector/${CDM_SUNOS_TAR}"

/usr/bin/tar $v -xzf  $CDM_SUNOS_TAR
StopIfError "Could not extract $CDM_SUNOS_TAR"

CDM_CERT_FILE=$(find ./ -name "rubrik.crt")
mv $v ${CDM_KEYS_DIR}/rubrik.crt ${CDM_KEYS_DIR}/rubrik.crt.orig
cp $v $CDM_CERT_FILE $CDM_KEYS_DIR
StopIfError "Could not copy replica CDM cluster certificate"

/usr/bin/chmod $v 600 ${CDM_KEYS_DIR}/rubrik.crt


LogPrint "Replica Rubrik (CDM) cluster certificate installed."
