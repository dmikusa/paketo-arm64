#!/bin/bash
set -eo pipefail

BPID="$1"
BPVER="$2"
WORK="./buildpacks"

if [ -z "$BPID" ] || [ -z "$BPVER" ]; then
	echo ""
	echo "USAGE:"
	echo "  clone.sh <buildpack-id> <buildpack-version>"
	echo ""
	echo "Enter the buildpack id/version for a composite buildpack."
	echo "The script will clone the composite and all component buildpacks."
	echo ""
	exit 255
fi

if [ -z "$WORK" ]; then
	echo "WORK cannot be empty"
	exit 254
fi

mkdir -p "$WORK"
rm -rf "${WORK:?}/"*

git clone "https://dashaun@github.com/$BPID" "$WORK/$BPID"
pushd "$WORK/$BPID" >/dev/null
git -c "advice.detachedHead=false" checkout "v$BPVER"
popd

for GROUP in $(yj -t < "$WORK/$BPID/buildpack.toml" | jq -rc '.order[].group[]'); do
	BUILDPACK=$(echo "$GROUP" | jq -r ".id")
	VERSION=$(echo "$GROUP" | jq -r ".version")
	git clone "https://dashaun@github.com/$BUILDPACK" "$WORK/$BUILDPACK"
	pushd "$WORK/$BUILDPACK" >/dev/null
	git -c "advice.detachedHead=false" checkout "v$VERSION"
	popd
done

