# the user has to do the main part here :-)
#
#
/opt/avamar/bin/avagent.bin --bindir="/opt/avamar/bin" --vardir="/opt/avamar/var" --sysdir="/opt/avamar/etc" --logfile="/tmp/avagent.log"
LogPrint "Please restore your backup in the Avamar WebGui (to path '/mnt/local/').
When finished enter 'touch /mnt/local/.autorelabel' to ensure that SELinux relabels the files on the next boot.
Afterwards type 'exit' in the shell to continue recovery, and then 'reboot'"
rear_shell "Did you restore the backup to /mnt/local ? Are you ready to continue recovery ?"
