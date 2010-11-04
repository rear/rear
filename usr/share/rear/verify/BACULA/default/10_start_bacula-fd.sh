#
# start the daemons!

bacula-fd -u root -g bacula -c /etc/bacula/bacula-fd.conf
ProgressStopIfError $?  "Cannot start bacula-fd file daemon."
