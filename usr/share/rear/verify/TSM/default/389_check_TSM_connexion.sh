# Use a first connection to the TSM server to request TSM PASSWD in case this one was not included in the
# ReaR rescue image.
# Note: ReaR uses fd6 for user input, fd7 for stdout and fd8 for stderr.
dsmc query mgmt 0<&6 1>&7 2>&8
