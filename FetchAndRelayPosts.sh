#!/bin/bash
#set -x

work_dir="$(dirname -- "${BASH_SOURCE[0]}")"
settings_file="${work_dir}/config.properties"
imported_file="${work_dir}/imported.txt"

# Check if search term is provided
if [ -z "$1" ]; then
	echo "Usage: $0 \"search words\""
	exit 1
else
	search_string="${1}"
fi

# Create imported.txt if it doesn't exist
if [ ! -f "${imported_file}" ]; then
	touch "${imported_file}"
fi

function read_settings {
	# Check if settings file is present and read settings
	if [ -f "${settings_file}" ]; then
		source "${settings_file}"
		if [ -n "${fake_relay_url}" ] && [ -n "${fake_relay_token}" ] && [ -n "${toot_path}" ] && [ -n "${mastodon_user}" ]; then
			return
		else
			echo "One or more settings are missing or empty in the settings file." >&2
			exit 1
		fi
	else
		echo "Settings file not found: ${settings_file}" >&2
		exit 1
	fi
}

function fetch_posts {
	# Run toot search and extract URIs from statuses
	uris=$("${toot_path}" --as "${mastodon_user}" search --json "${search_string}" | jq -r '.statuses[]?.uri')

	# Loop through each URI and run curl command
	while IFS= read -r uri; do
		if [ -n "${uri}" ]; then
			# Check if URI already exists in imported.txt
			if grep -Fxq "${uri}" "${imported_file}"; then
				echo "Skipping (already imported): ${uri}"
			else
				echo "Processing: ${uri}"
				curl -X "POST" "${fake_relay_url}" \
					-H "Authorization: Bearer ${fake_relay_token}" \
					-H 'Content-Type: application/x-www-form-urlencoded; charset=utf-8' \
					--data-urlencode "statusUrl=${uri}"

				# Add URI to imported.txt
				echo "${uri}" >>"${imported_file}"
			fi
		fi
	done <<<"${uris}"
}

read_settings
fetch_posts
