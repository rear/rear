
# Check file:// tape:// usb:// BACKUP_URL and OUTPUT_URL for incorrect usage

# Use generic wording in error messages because prep/default/020_translate_url.sh
# may translate a BACKUP_URL into an OUTPUT_URL so that errors in a BACKUP_URL
# may appear when testing the translated/derived OUTPUT_URL
# see https://github.com/rear/rear/issues/925

# First steps to be prepared for 'se -e' which means
# replacing COMMAND ; StopIfError ...
# with COMMAND || Error ...

# See lib/global-functions.sh what the url_* functions actually result and
# see prep/NETFS/default/050_check_NETFS_requirements.sh for valid BACKUP_URLs

local url=""
for url in "$BACKUP_URL" "$OUTPUT_URL" ; do
    test "$url" || continue
    local scheme="$( url_scheme "$url" )"
    local authority="$( url_host "$url" )"
    local path="$( url_path "$url" )"
    case "$scheme" in
        (file|tape|usb)
            # file:// tape:// usb:// URLs must not have an authority part (scheme://authority/path)
            # i.e. file:// tape:// usb:// URLs must have an empty authority part (scheme:///path)
            test "$authority" && Error "BACKUP_URL or OUTPUT_URL '$url' requires triple slash (i.e. '$scheme:///path')"
            # file:// tape:// usb:// URLs must have a non-empty path
            test "$path" || Error "BACKUP_URL or OUTPUT_URL '$url' is missing a path (i.e. '$scheme:///path')"
            ;;
    esac
done

