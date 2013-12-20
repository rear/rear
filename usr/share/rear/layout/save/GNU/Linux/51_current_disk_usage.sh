# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

# Save the current disk usage (POSIX output format) in the rescue image
df -Plh > $VAR_DIR/layout/config/df.txt
