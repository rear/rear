# when booted from rear archive the only only workflow(s) are:
# - recover

# when booted from rear image then the file /etc/rear-release is unique and does not exist in production
if [[ -f /etc/rear-release ]] && [[ "$WORKFLOW" != "recover" ]] ; then
    Error "The workflow $WORKFLOW is not supported when booted from rear rescue image"
fi
