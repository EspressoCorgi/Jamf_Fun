#!/bin/bash

# Get the current logged-in user's home directory
user_home_dir=$(eval echo "~$(whoami)")

# Jamf Pro server URL
jamfProURL="https://server.jamfcloud.com"

# Jamf API credentials - Consider using environment variables for these
jamfusername="username"
jamfpassword="password"

# Define the CSV file name with the desired format
currentDate=$(date "+%Y-%m-%d")
csvFileName="bad_policy_names_$currentDate.csv"

# Define the output directory as a temporary directory
OUTPUT_DIR=$(mktemp -d)

# Function to sanitize policy names
sanitize_policy_name() {
    local policy_name="$1"
    # Remove HTML tags and special characters from the policy name
    sanitized_name=$(echo "$policy_name" | sed 's/<[^>]*>//g' | tr -d '[:punct:]')
    echo "$sanitized_name"
}

# Function to export a policy
export_policy() {
    local policy_id="$1"
    local policy_name="$2"

    # Sanitize the policy name
    sanitized_policy_name=$(sanitize_policy_name "$policy_name")

    # Export the policy to a temporary XML file
    local temp_xml=$(mktemp)
    if curl -o "$temp_xml" -u "$jamfusername:$jamfpassword" "$jamfProURL/JSSResource/policies/id/$policy_id" >/dev/null 2>&1; then
        echo "Exported policy: $sanitized_policy_name (ID: $policy_id)"
        # Extract the site ID from the policy XML
        site_id=$(xmlstarlet sel -t -v "//site/id" "$temp_xml")
        # Fetch the site name based on the site ID
        site_name=$(curl -s -u "$jamfusername:$jamfpassword" "$jamfProURL/JSSResource/sites/id/$site_id" | xmlstarlet sel -t -v "//site/name")
        # Append sanitized policy name, ID, and site name to the CSV file in the user's "Downloads" folder
        echo "$sanitized_policy_name,$policy_id,$site_name" >> "$user_home_dir/Downloads/$csvFileName"
    else
        echo "Failed to export policy: $sanitized_policy_name (ID: $policy_id)"
    fi

    # Remove the temporary XML file
    rm -f "$temp_xml"
}

# Trap the script exit to ensure cleanup
cleanup_temp_directory() {
    rm -rf "$OUTPUT_DIR"
}
trap cleanup_temp_directory EXIT

# Get the list of all policies from Jamf Pro in XML format
policies_xml=$(curl -s -u "$jamfusername:$jamfpassword" "$jamfProURL/JSSResource/policies")

# Write the CSV file header in the user's "Downloads" folder
echo "Policy Name,Policy ID,Site Name" > "$user_home_dir/Downloads/$csvFileName"

# Define the abbreviations to filter policies
abbreviations=("Global" "AS" "ATH" "CD" "CAS" "ENG" "TAMUG" "TAMUH" "ITR" "ITSAP" "LCR" "RL" "PVFA" "SVM" "TS")

# Initialize a counter for exported policies
exportedPolicyCount=0

# Loop through each policy and check if it meets the criteria
while IFS= read -r line; do
    # Separate the policy ID and name
    policy_id=$(echo "$line" | cut -f1)
    policy_name=$(echo "$line" | cut -f2-)

    # Remove leading and trailing spaces from policy name
    policy_name=$(echo "$policy_name" | xargs)

    # Check if the policy name contains any of the abbreviations
    matched=false
    for abbreviation in "${abbreviations[@]}"; do
        if [[ "$policy_name" == *"$abbreviation"* ]]; then
            matched=true
            break
        fi
    done

    # Export the policy if it doesn't match any abbreviation
    if [ "$matched" = false ]; then
        export_policy "$policy_id" "$policy_name"
        ((exportedPolicyCount++))
    fi
done < <(echo "$policies_xml" | xmlstarlet sel -t -m "//policy" -v "id" -o $'\t' -v "name" -n)

# Update the CSV file in the user's "Downloads" folder with the total number of exported policies
echo "Total Policies,$exportedPolicyCount" >> "$user_home_dir/Downloads/$csvFileName"

echo "Exported policies that do not meet the criteria to $user_home_dir/Downloads/$csvFileName"
This updated script includes a sanitize_policy_name function that removes HTML tags and special characters from policy names before exporting them to the CSV file. This should help prevent parsing errors caused by unexpected HTML content in policy names.