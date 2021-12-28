#!/bin/bash
set -eo pipefail

PKGTOML="$1"

if [ -z "$PKGTOML" ]; then
	echo ""
	echo "USAGE:"
	echo "  mod-pkgtoml.sh <package.toml-path>"
	echo ""
	echo "Enter the path to package.toml."
	echo "The script will update package.toml and change the id to end with '-arm64'."
	echo ""
	exit 255
fi

if ! [ -f "$PKGTOML" ]; then
	echo "[$PKGTOML] does not exist"
	exit 254
fi

NEW=$(yj -t < "$PKGTOML" | jq -r '.dependencies[].uri |= sub("(?<bp>^.*):(?<ver>.*)$"; .bp + "-arm64:" + .ver)' | yj -jti)
echo "$NEW" > "$PKGTOML"
