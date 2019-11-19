# 430_gen_rbs_uuid_for_cdm.sh
# Reset the UUID used by RBS if the IP address has changed

CDM_RBA_DIR=/etc/rubrik
CDM_AGENT_UUID=${CDM_RBA_DIR}/conf/uuid

# When USER_INPUT_CDM_SAME_AGENT_UUID has Does this client have the same IP address as the original 'y' was actually meant:
LogPrint ""
LogPrint "Found the following IP addresses on this system:"
LogPrint "$( ip addr | grep inet | cut -d / -f 1 | grep -v 127.0.0.1 | grep -v ::1 )"
LogPrint ""
is_true "$USER_INPUT_CDM_SAME_AGENT_UUID" && USER_INPUT_SAME_AGENT_UUID="y"
while true ; do
    # Find out if the IP address has changed from the original. If so generate a new UUID.
    # the default (i.e. the automated response after the timeout) should be 'n':
    answer="$( UserInput -I CDM_SAME_AGENT_UUID -p "Does this client have the same IP address as the original? (y/n)" -D 'y' -t 300 )"
    is_true "$answer" && return 0
    if is_false "$answer" ; then
        break
    fi
    UserOutput "Please answer 'y' or 'n'"
done

mv $v ${CDM_AGENT_UUID} ${CDM_AGENT_UUID}.old
/usr/bin/uuidgen | tee -a ${CDM_AGENT_UUID} >&2
StopIfError "Unable to generate new UUID"

CDM_NEW_AGENT_UUID="true"
LogPrint "Rubrik (CDM) RBS agent now has new UUID."
