# When booted from ReaR image the only only workflow is 'recover' and
# when booted from ReaR image /etc/rear-release is unique (does not exist otherwise):
if [[ -f /etc/rear-release ]] && [[ "$WORKFLOW" != "recover" ]] ; then
    Error "The workflow $WORKFLOW is not supported when booted from ReaR rescue image"
fi
