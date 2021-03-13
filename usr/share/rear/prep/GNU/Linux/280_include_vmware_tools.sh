# $Id$
#
# recent vmware tools (or maybe it is just open-vm-tools on SUSE) keep their modules
# outside the /lib/modules path. To cope with that we add the vmware-tools if vmxnet
# is loaded but modinfo cannot find it.

if lsmod | grep -q -E '^vmxnet\b'; then
	if ! modinfo vmxnet >/dev/null 2>&1; then
		COPY_AS_IS+=( /usr/lib*/vmware-tools )
		Log "Including '/usr/lib*/vmware-tools'"
	fi
fi
