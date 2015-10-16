# start included NBK DC client so file restore can happen:

echo "Sourcing $SHARE_DIR/lib/nbkdc-functions.sh"
source $SHARE_DIR/lib/nbkdc-functions.sh

# Check if working directories of NBK DC datamover exist
if [ ! -d $NBKDC_HIBLST_DIR ]; then
	mkdir $NBKDC_HIBLST_DIR
fi
if [ ! -d $NBKDC_HIBTMP_DIR ]; then
	mkdir $NBKDC_HIBTMP_DIR
fi
if [ ! -d $NBKDC_HIBTPD_DIR ]; then
	mkdir $NBKDC_HIBTPD_DIR
fi
if [ ! -d $NBKDC_HIBTAP_DIR ]; then
	mkdir $NBKDC_HIBTAP_DIR
fi
if [ ! -d $NBKDC_HIBMSG_DIR ]; then
	mkdir $NBKDC_HIBMSG_DIR
fi
if [ ! -d $NBKDC_HIBLOG_DIR ]; then
	mkdir $NBKDC_HIBLOG_DIR
fi

# Run a checkscript for the datamover to set required soft links
if [ -e $NBKDC_HIB_DIR/finHib ]; then
	if [ -x $NBKDC_HIB_DIR/finHib ]; then
		cd $NBKDC_HIB_DIR && ./finHib
	else 
		chmod +x $NBKDC_HIB_DIR/finHib
		cd $NBKDC_HIB_DIR && ./finHib
	fi
fi

# Now run the NBK DC agent so we can accept restore jobs
if [ -e $NBKDC_DIR/rcmd-executor/rcmd-executor ]; then
	
	exec $NBKDC_DIR/rcmd-executor/rcmd-executor run &
else 
	LogPrint "Cannot start the NovaBACKUP agent in $NBKDC_DIR/rcmd-executor !!!!

	Please check the NBK DC installation directory $NBKDC_DIR 

	"
fi
