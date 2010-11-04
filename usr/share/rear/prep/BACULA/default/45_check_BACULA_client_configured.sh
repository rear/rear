#
# Check that bacula is installed and configuration files exist
# Binaries: /usr/sbin/bacula-fd, /usr/sbin/bconsole
# Directories:	/var/lib/bacula (must be empty)
#		/etc/bacula
# Files: /etc/bacula/bacula-fd.conf, /etc/bacula/bconsole.conf
#

# executables
type -p bacula-fd 2>/dev/null >/dev/null 
ProgressStopIfError $? "Bacula File Daemon is missing"
type -p bconsole 2>/dev/null >/dev/null
ProgressStopIfError $? "Bacula console executable is missing"
# Configuration files
if test ! -s /etc/bacula/bacula-fd.conf  -a ! -s /etc/bacula/bconsole.conf; then
	 ProgressStopIfError 1  "Bacula configuration files missing [/etc/bacula/]"
fi
