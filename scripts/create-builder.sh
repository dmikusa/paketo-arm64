#!/bin/bash
set -eo pipefail

BPID="$1"
BPVER="$2"
LFCVER="$3"
RUNIMG="$4"
BLDIMG="$5"
STACKID="$6"
BLDRIMG="$7"
WORK="./buildpacks"

if [ -z "$BPID" ] || [ -z "$BPVER" ] || [ -z "$RUNIMG" ] || [ -z "$BLDIMG" ] || [ -z "$STACKID" ] || [ -z "$BLDRIMG" ]; then
	echo ""
	echo "USAGE:"
	echo "  create-builder.sh <buildpack-id> <buildpack-version> <lifecycle-version> <run-img> <build-img> <stack-id> <builder-id>"
	echo ""
	echo "Enter the required info in order:"
    echo " - buildpack id"
    echo " - buildpack version"
    echo " - a lifecycle version"
    echo " - run image"
    echo " - build image"
    echo " - stack id"
    echo " - builder image"
    echo ""
	echo "The script will create a builder.toml from the composite buildpack."
    echo "This may not be 100% accurate, but should be close."
	echo ""
	exit 255
fi

if [ -z "$WORK" ] && ! [ -d "$WORK" ]; then
	echo "WORK cannot be empty and must exist"
	exit 254
fi

BPTOML="$WORK/$BPID/buildpack.toml"

if ! [ -f "$BPTOML" ]; then
    echo "Cannot find [$BPTOML]"
    exit 253
fi

BLDRTOML="$WORK/builder/builder.toml"
mkdir -p "$(dirname $BLDRTOML)"

desc() {
    echo "description = \"An ARM64 builder based on $BPID\""
    echo ""
}

buildpacks() {
    for GROUP in $(yj -t < "$WORK/$BPID/buildpack.toml" | jq -rc '.order[].group[]'); do
        BUILDPACK=$(echo "$GROUP" | jq -r ".id")
        VERSION=$(echo "$GROUP" | jq -r ".version")
        echo "[[buildpacks]]"
        echo "  id = \"$BUILDPACK-arm64\""
        echo "  version = \"$VERSION\""
        echo "  uri = \"docker://docker.io/$BUILDPACK-arm64:$VERSION\""
        echo ""
    done
}

lifecycle() {
    cat << EOF
[lifecycle]
  uri = "https://github.com/buildpacks/lifecycle/releases/download/v${LFCVER}/lifecycle-v${LFCVER}+linux.arm64.tgz"

EOF
}

order() {
    yj -t < "$BPTOML" | jq -r '{"order": .order} | .order[].group[].id |= . + "-arm64"' | yj -jti
    echo ""
}

stack() {
    cat << EOF
[stack]
  build-image = "$BLDIMG"
  id = "$STACKID"
  run-image = "$RUNIMG"

EOF
}

{ desc; buildpacks; lifecycle; order; stack; } > "$BLDRTOML"

# use pull-policy never so that we alway use the local docker image that we just built
# without this, it may pull down different docker images and use them instead
sudo pack builder create "$BLDRIMG" -c "$BLDRTOML" --pull-policy never