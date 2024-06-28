LogPrint "Connecting to the Bareos Director ..."

# We use features introduced with Bareos 20 (show filesets in JSON API mode).
# As the oldest Bareos version supported by bareos.com is 21
# we add this as a requirement.
BAREOS_DIRECTOR_VERSION=$( bcommand_json "version" | jq --exit-status --raw-output '.result[].version' )
LogPrint "Bareos Direction version is $BAREOS_DIRECTOR_VERSION"
local major_version=${BAREOS_DIRECTOR_VERSION%%.*}
if ! [[ $major_version =~ ^[0-9]+$ ]] || (( major_version < 21 )); then
    Error "Bareos Director > 21 is required."
fi
