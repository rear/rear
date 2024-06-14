### Create example bootstrap file
cat <<EOF >"$VAR_DIR/bootstrap.txt"
### Example Bareos bootstrap file
###

### Only the exact Volume name is required, other keywords are optional.
### The use of FileIndex and Count keywords speeds up the selection enormously.

### The Volume name to use
Volume=PLEASE-EDIT-BOOTSTRAP

### A (list of) Client name(s) to be matched on the current Volume
#Client=$(hostname -s)-fd

### A (list or range of) JobId(s) to be selected from the current Volume
#JobId=18

### A (list of) Job name(s) to be matched on the current Volume
#Job=Bkp_Daily.2011-06-16

### A (list or range of) Volume session id(s) to be matched from the current Volume
#VolSessionId=1

### The Volume session time to be matched from the current Volume
#VolSessionTime=108927638

### A (list or range of) FileIndex(es) to be selected from the current Volume
#FileIndex=1-157

### The total number of files that will be restored for this Volume.
#Count=157
EOF
#############################################################################
