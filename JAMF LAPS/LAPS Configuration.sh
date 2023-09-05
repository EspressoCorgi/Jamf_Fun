#!/bin/bash

# Set your Jamf Pro server URL
jamfProURL="jamfserver.jamfcloud.com"

# Set your Jamf User and Password
jamfusername="your_username"
jamfpassword="your_password"

# Request auth token
authToken=$(curl \
  --request POST \
  --silent \
  --url "$jamfProURL/api/v1/auth/token" \
  --user "$jamfusername:$jamfpassword")

# Parse auth token
token=$(echo "$authToken" | jq -r '.token')
tokenExpiration=$(echo "$authToken" | jq -r '.expires')

# Set LAPS settings
# Having the value of "true" will enable laps
curl -X 'PUT' \
  "$jamfProURL/api/v2/local-admin-password/settings" \
  -H 'accept: application/json' \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -d '{
  "autoDeployEnabled": true,
  "passwordRotationTime": 3600,
  "autoRotateEnabled": true,
  "autoRotateExpirationTime": 7776000
}'

# Expire auth token
curl --header "Authorization: Bearer $token" \
  --request POST \
  --silent \
  --url "$jamfProURL/api/v1/auth/invalidate-token"
