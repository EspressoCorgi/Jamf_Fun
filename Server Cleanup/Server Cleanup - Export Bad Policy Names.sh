#!/bin/bash

# Jamf Pro server URL
jamfProURL="your_server_url_here"

# Jamf API credentials - Consider using environment variables for these
jamfusername="your_username_here"
jamfpassword="your_password_here"

# Define the CSV file name with the desired format
currentDate=$(date "+%Y-%m-%d")
csvFileName="bad_policy_names_$currentDate.csv"

# Define the output directory as a temporary directory
OUTPUT_DIR=$(mktemp -d)

# Function to export a policy
export_policy() {
    local policy_id="$1"
    local policy_name="$2"
    local output_dir="$3"

    # Export the policy
    if curl -o "$output_dir/$policy_name.xml" -u "$jamfusername:$jamfpassword" "$jamfProURL/JSSResource/policies/id/$policy_id" >/dev/null 2>&1; then
        echo "Exported policy: $policy_name (ID: $policy_id)"
    else
        echo "Failed to export policy: $policy_name (ID: $policy_id)"
    fi

    # Append policy name and ID to the CSV file
    echo "$policy_name,$policy_id" >> "$csvFilePath"
}

# Trap the script exit to ensure cleanup
cleanup_temp_directory() {
    rm -rf "$OUTPUT_DIR"
}
trap cleanup_temp_directory EXIT

# Get the list of all policies from Jamf Pro in XML format
policies_xml=$(curl -s -u "$jamfusername:$jamfpassword" "$jamfProURL/JSSResource/policies")

# Define the CSV file path
csvFilePath="$OUTPUT_DIR/$csvFileName"

# Write the CSV file header
echo "Policy Name,Policy ID" > "$csvFilePath"

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
        export_policy "$policy_id" "$policy_name" "$OUTPUT_DIR"
        ((exportedPolicyCount++))
    fi
done < <(echo "$policies_xml" | xmlstarlet sel -t -m "//policy" -v "id" -o $'\t' -v "name" -n)

# Update the CSV file with the total number of exported policies
echo "Total Policies,$exportedPolicyCount" >> "$csvFilePath"

echo "Exported policies that do not meet the criteria to $OUTPUT_DIR"
