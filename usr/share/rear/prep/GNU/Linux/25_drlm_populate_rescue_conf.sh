# Set DRLM given variables to rescue.conf
# as we need this variables at recovery time.

if [ "$DRLM_MANAGED" == "y" ]; then
	drlm_set_rescue_conf
fi
