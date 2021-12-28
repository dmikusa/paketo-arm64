#!/bin/bash
set -eo pipefail

BPTOML="$1"

if [ -z "$BPTOML" ]; then
	echo ""
	echo "USAGE:"
	echo "  update.sh <buildpack.toml-path>"
	echo ""
	echo "Enter the path to buildpack.toml."
	echo "The script will update buildpack.toml and change the id to end with '-arm64'."
	echo ""
	exit 255
fi

if ! [ -f "$BPTOML" ]; then
	echo "[$BPTOML] does not exist"
	exit 254
fi

NEW=$(yj -t < "$BPTOML" | jq -r '.buildpack.id |= . + "-arm64"' | yj -jti)
echo "$NEW" > "$BPTOML"
