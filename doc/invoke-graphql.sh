#!/bin/sh

# Demonstration of invoking GraphQL directly

curl \
	-i \
	-X POST \
	-H "Content-Type: application/json" \
	-H "X-Okapi-Url: https://folio-snapshot-okapi.dev.folio.org" \
	-H "X-Okapi-Tenant: diku" \
	-H "X-Okapi-Token: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJkaWt1X2FkbWluIiwidXNlcl9pZCI6IjExODFhMTk0LWRiY2YtNWVkYS1hODRlLTRhYzcxYmZhZjdlMiIsImlhdCI6MTU5NzkyODE3NCwidGVuYW50IjoiZGlrdSJ9.F5XDQY9NHKh-HE66B_j0MMs0yPw3BvGO0UR90TFTLtY" \
	-d '{ "query": "query { instance_storage_instances { instances { title contributors { name } } } }" }' \
	http://localhost:3001/graphql
