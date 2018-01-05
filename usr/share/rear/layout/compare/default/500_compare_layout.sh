# Test if ORIG_LAYOUT and TEMP_LAYOUT are the same.

# Usually ORIG_LAYOUT is of the form var/lib/rear/layout/disklayout.conf
# and TEMP_LAYOUT is of the form /tmp/rear.XXXX/tmp/checklayout.conf
# see lib/checklayout-workflow.sh

# In case of btrfs the ordering of the btrfsmountedsubvol entries is random
# so that plain 'cmp' would detect changes unless the entries were sorted
# see https://github.com/rear/rear/issues/1657
if cmp -s <( grep -v '^#' $ORIG_LAYOUT | sort ) <( grep -v '^#' $TEMP_LAYOUT | sort ) ; then
    LogPrint "Disk layout is identical"
else
    # The 'cmp' exit status is 0 if inputs are the same, 1 if different, 2 if trouble.
    # In case of 'trouble' do the same as when the layout has changed to be on the safe side:
    LogPrint "Disk layout has changed"
    # In the log file show the changes in the right ordering in the layout files:
    diff -U0 <( grep -v '^#' $ORIG_LAYOUT ) <( grep -v '^#' $TEMP_LAYOUT ) 1>&2
    EXIT_CODE=1
fi

