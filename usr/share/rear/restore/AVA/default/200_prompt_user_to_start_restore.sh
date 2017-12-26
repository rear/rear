# the user has to do the main part here :-)
#
#
$AVA_ROOT_DIR/bin/avagent.bin --bindir="$AVA_ROOT_DIR/bin" --vardir="$AVA_ROOT_DIR/var" --sysdir="$AVA_ROOT_DIR/etc" --logfile="/tmp/avagent.log" 0<&6 1>&7 2>&8
LogPrint "Please restore your backup in the Avamar WebGui (to path '/mnt/local/').
When finished enter 'touch /mnt/local/.autorelabel' to ensure that SELinux relabels the files on the next boot.
Afterwards type 'exit' in the shell to continue recovery, and then 'reboot'"
rear_shell "Did you restore the backup to /mnt/local ? Are you ready to continue recovery ?"
