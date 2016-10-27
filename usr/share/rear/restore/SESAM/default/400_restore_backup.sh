LogPrint "

The System is now ready for restore. Please start the restore task from the SEP Sesam graphical user interface!

! Remember that the restore target must be set to '$TARGET_FS_ROOT' !

For further documentation see the following link:

 http://wiki.sepsoftware.com/wiki/index.php/Disaster_Recovery_for_Linux_3.0_en

after the restore has finished quit this wizard with the command 'exit' to continue.
"

rear_shell "Did you restore the backup to $TARGET_FS_ROOT ? Are you ready to continue recovery ?"

