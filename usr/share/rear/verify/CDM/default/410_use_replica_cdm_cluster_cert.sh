# 410_use_replica_cdm_cluster_cert.sh
# If restoring from a replica Rubrik (CDM) cluster use it's cert for RBS.

LogPrint "If restoring from a replica Rubrik (CDM) cluster it's cert will be downloaded and used for RBS"

CDM_RBA_DIR=/etc/rubrik
CDM_KEYS_DIR=${CDM_RBA_DIR}/keys

# When USER_INPUT_CDM_REPLICA_CLUSTER has any 'true' value be liberal in what you accept and assume exactly 'y' was actually meant:
is_true "$USER_INPUT_CDM_REPLICA_CLUSTER" && USER_INPUT_CDM_REPLICA_CLUSTER="y"
local prompt="Is the data being restored from the original CDM Cluster?"
local input_value=""
local wilful_input=""
while true ; do
    # Find out if the restore is being done from the original CDM cluster or a Replica
    # the default (i.e. the automated response after the timeout) should be 'no':
    input_value="$( UserInput -I CDM_REPLICA_CLUSTER -p "$prompt" -D 'no' )" && wilful_input="yes" || wilful_input="no"
    if is_false "$input_value" ; then
        if is_true "$wilful_input" ; then
            LogPrint "User confirmed the data is not being restored from the original CDM Cluster"
        else
            LogPrint "Assuming the data is not being restored from the original CDM Cluster"
        fi
        break
    fi
    is_true "$input_value" ; then
        LogPrint "User confirmed the data is being restored from the original CDM Cluster"
        return 0
    fi
done

LogPrint "Downloading cert from replica CDM cluster"
# The name of the tar file that is being downloaded has changed in Rubrik CDM v5.1.
# Before Rubrik CDM v5.1 it was rubrik-agent-sunos5.10.sparc.tar.gz
# since Rubrik CDM v5.1 it is rubrik-agent-solaris.sparc.tar.gz
# cf. https://github.com/rear/rear/issues/2441
CDM_SUNOS_TAR=rubrik-agent-sunos5.10.sparc.tar.gz
CDM_SOLARIS_TAR=rubrik-agent-solaris.sparc.tar.gz
pushd $TMPDIR
while true ; do
    prompt="Enter one of the IP addresses for the replica CDM cluster (or 'no' to cancel): "
    CDM_CLUSTER_IP="$( UserInput -I USER_INPUT_CDM_CLUSTER_IP -r -t 0 -p "$prompt" )"
    test $CDM_CLUSTER_IP || continue
    if is_false "$CDM_CLUSTER_IP" ; then
        LogPrint "User canceled downloading cert from replica CDM cluster (data restore may fail now)"
        popd
        return 0
    fi
    for CDM_TAR_FILE in $CDM_SOLARIS_TAR $CDM_SUNOS_TAR '' ; do
        curl $v -fskLOJ https://${CDM_CLUSTER_IP}/connector/${CDM_TAR_FILE} && break
    done
    if ! test -s "$CDM_TAR_FILE" ; then
        LogPrintError "Could not download Rubrik agent from https://${CDM_CLUSTER_IP}/connector/${CDM_SOLARIS_TAR} or https://${CDM_CLUSTER_IP}/connector/${CDM_SUNOS_TAR}"
        continue
    fi
    if ! tar $v -xzf $CDM_TAR_FILE ; then
        LogPrintError "Could not extract $CDM_TAR_FILE"
        continue
    fi
    CDM_CERT_FILE=$(find ./ -name "rubrik.crt")
    mv $v ${CDM_KEYS_DIR}/rubrik.crt ${CDM_KEYS_DIR}/rubrik.crt.orig
    if ! cp $v $CDM_CERT_FILE $CDM_KEYS_DIR ; then
        LogPrintError "Could not copy replica CDM cluster certificate"
        continue
    fi
    chmod $v 600 ${CDM_KEYS_DIR}/rubrik.crt
    mv $v ${CDM_KEYS_DIR}/agent.crt ${CDM_KEYS_DIR}/agent.crt.orig
    mv $v ${CDM_KEYS_DIR}/agent.pem ${CDM_KEYS_DIR}/agent.pem.orig
    # FIXME: Why is there no test whether or not /etc/rubrik/rba-keygen.sh succeeded?
    # Is it perhaps only optional?
    # cf. https://github.com/rear/rear/pull/2445#discussion_r448217873
    /etc/rubrik/rba-keygen.sh
    break
done
popd
LogPrint "Replica Rubrik (CDM) cluster certificate installed"
