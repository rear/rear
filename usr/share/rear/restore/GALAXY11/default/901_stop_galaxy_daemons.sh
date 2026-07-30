#
# stop commvault daemons to prevent backups from being scheduled in the rescue system
#
#
#

# we ignore errors because this is a safety measure and the recovery should proceed regardless
Galaxy stop || :
