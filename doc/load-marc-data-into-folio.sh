#!/bin/sh

if [ $# -ne 1 ]; then
   echo "Usage: $0 <MARCfile>" >&2
   exit 1
fi
filename="$1"

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
	--data-binary "$filename" \
		> $tmpfile2

echo "=== Stage 3 ==="
curl --silent --location --request POST "$OKAPI_URL/data-import/uploadDefinitions/$uploadDefinitionId/processFiles?defaultMapping=true" \
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
