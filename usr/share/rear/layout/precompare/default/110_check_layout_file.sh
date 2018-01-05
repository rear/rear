
# Check if an original disk layout file already exists:
test -s "$ORIG_LAYOUT" || Error "No (non-empty) $ORIG_LAYOUT file (needs to be created before e.g. via 'rear mkrescue/mkbackup')"

