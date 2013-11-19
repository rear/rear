# As umask can vary on different systems, we've to set it to a secure value
# before we're start writing any files. With a defined umask of 0077, further
# files will automatically be written with root permissions only.
#
# Author: dbarton, confirm IT solutions
#

Log "Setting umask to 077"
umask 0077
