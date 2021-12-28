#!/bin/bash
set -eo pipefail

BPID="$1"
BPVER="$2"
WORK="./buildpacks-tmp"

if [ -z "$BPID" ] || [ -z "$BPVER" ]; then
	echo ""
	echo "USAGE:"
	echo "  reset.sh <buildpack-id> <buildpack-version>"
	echo ""
	echo "Enter the buildpack id/version for a composite buildpack."
	echo "The script will reset and clear out any changes."
	echo "It can also be used to update, if the composite buildpack has been updated."
	echo "This requires a directory setup in advance, like what you get from running 'clone.sh'."
	echo ""
	exit 255
fi

if [ -z "$WORK" ] && ! [ -d "$WORK" ]; then
	echo "WORK cannot be empty and must exist"
	exit 254
fi

pushd "$WORK/$BPID" >/dev/null
git reset --hard HEAD
git checkout main
git pull
git -c "advice.detachedHead=false" checkout "v$BPVER"
popd

for GROUP in $(yj -t < "$WORK/$BPID/buildpack.toml" | jq -rc '.order[].group[]'); do
	BUILDPACK=$(echo "$GROUP" | jq -r ".id")
	VERSION=$(echo "$GROUP" | jq -r ".version")
	pushd "$WORK/$BUILDPACK" >/dev/null
        git reset --hard HEAD
	git checkout main
	git pull
	git -c "advice.detachedHead=false" checkout "v$VERSION"
	popd
done

