#!/bin/bash

# Function to generate a random password
generate_random_password() {
  tr -dc '[:alnum:]' < /dev/urandom | fold -w16 | head -n1
}

# Set the Jamf Pro API credentials and server URL
jamfProURL="https://tamu.jamfcloud.com"
jamfusername="shem-admin"
jamfpassword="iCif8mFCrNi3Lx9rHGxd6?CeN"

# Request auth token
authToken=$( /usr/bin/curl \
--request POST \
--silent \
--url "$jamfProURL/api/v1/auth/token" \
--user "$jamfusername:$jamfpassword" )

# Parse auth token
token=$( /usr/bin/plutil \
-extract token raw - <<< "$authToken" )

tokenExpiration=$( /usr/bin/plutil \
-extract expires raw - <<< "$authToken" )

localTokenExpirationEpoch=$( TZ=GMT /bin/date -j \
-f "%Y-%m-%dT%T" "$tokenExpiration" \
+"%s" 2> /dev/null )

# Prompt the user for inputs using osascript
username=$(osascript -e 'text returned of (display dialog "Enter Username:" default answer "")')
full_name=$(osascript -e 'text returned of (display dialog "Enter Full Name:" default answer "")')
email=$(osascript -e 'text returned of (display dialog "Enter Email:" default answer "")')

# Generate a random password
password=$(generate_random_password)

# Set the group membership
group_membership="CSCN - Jamf Pro Production Admin Console - Auditors with Computer and Mobile Device Update Access"

# Create the user account in Jamf Pro
curl -X POST \
  --header "Authorization: Bearer $token" \
  -H "Content-Type: application/xml" \
  -d "<?xml version='1.0' encoding='utf-8'?>
  <user>
    <access_level>Group Access</access_level>
    <access_status>enabled</access_status>
    <username>$username</username>
    <full_name>$full_name</full_name>
    <email>$email</email>
    <password>$password</password>
    <group_membership>$group_membership</group_membership>
  </user>" \
  "$jamfProURL/JSSResource/accounts/user/$username"

# Expire auth token
/usr/bin/curl \
--header "Authorization: Bearer $token" \
--request POST \
--silent \
--url "$jamfProURL/api/v1/auth/invalidate-token"

echo "User account created successfully."
