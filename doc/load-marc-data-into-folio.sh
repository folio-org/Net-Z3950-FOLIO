#!/bin/sh

# First log into a back-end FOLIO system. storing the Okapi URL,
# tenant and token in the file `.okapi` in the home directory:
#
#	OKAPI_URL=https://folio-snapshot-stable-okapi.dev.folio.org
#	OKAPI_TENANT=diku
#	OKAPI_TOKEN=123abc
#
# You can conveniently do this using `okapi login` with this CLI:
# https://github.com/thefrontside/okapi.rb
#
# Then invoke as: ./load-marc-data-into-folio.sh sample100.marc

if [ $# -ne 1 ]; then
   echo "Usage: $0 <MARCfile>" >&2
   exit 1
fi
filename="$1"
if [ ! -f "$filename" ]; then
    echo "$0: no such MARC file: $filename" >&2
    exit 2
fi

. ~/.okapi
tmpfile1=`mktemp`
tmpfile2=`mktemp`
trap 'rm -f $tmpfile1 $tmpfile2' 1 15 0

echo "=== Stage 1 ==="
curl --silent --location --request POST "$OKAPI_URL/data-import/uploadDefinitions" \
	--header "Content-Type: application/json" \
	--header "X-Okapi-Tenant: $OKAPI_TENANT" \
	--header "X-Okapi-Token: $OKAPI_TOKEN" \
	--data-raw "{ \"fileDefinitions\": [{ \"name\": \"$filename\" }] }" \
		> $tmpfile1

uploadDefinitionId=`jq -r -M .id $tmpfile1`
fileDefinitionId=`jq -r -M '.fileDefinitions[0].id' $tmpfile1`
# echo
# echo "uploadDefinitionId=$uploadDefinitionId"
# echo "fileDefinitionId=$fileDefinitionId"

echo "=== Stage 2 ==="
curl --silent --location --request POST "$OKAPI_URL/data-import/uploadDefinitions/$uploadDefinitionId/files/$fileDefinitionId" \
	--header "Content-Type: application/octet-stream" \
	--header "X-Okapi-Tenant: $OKAPI_TENANT" \
	--header "X-Okapi-Token: $OKAPI_TOKEN" \
	--data-binary "@$filename" \
		> $tmpfile2

echo "=== Stage 3 ==="
curl -i --silent --location --request POST "$OKAPI_URL/data-import/uploadDefinitions/$uploadDefinitionId/processFiles?defaultMapping=true" \
	--header "Content-Type: application/json" \
	--header "X-Okapi-Tenant: $OKAPI_TENANT" \
	--header "X-Okapi-Token: $OKAPI_TOKEN" \
	--data-raw "{
		\"uploadDefinition\": `cat $tmpfile2`,
		\"jobProfileInfo\": {
		  \"id\": \"22fafcc3-f582-493d-88b0-3c538480cd83\",
		  \"name\": \"Create MARC Bibs\",
		  \"dataType\": \"MARC\"
		}
	      }"
