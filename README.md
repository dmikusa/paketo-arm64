# Paketo Buildpacks ARM64 Build Instructions

## Prerequisites

1. Get yourself some ARM64 hardware (Mac M1) or a VM (Oracle Cloud has free ARM64 VMs)
2. Install some basic packages: make, curl, git, jq
3. Install Go. Follow instructions here.
4. This is used later to package buildpacks: `GO111MODULE=on go get -u -ldflags="-s -w" github.com/paketo-buildpacks/libpak/cmd/create-package`
5. Install `yj` which is used by some of the helper scripts. Get it from [here](https://github.com/sclevine/yj/releases). Copy to `/usr/local/bin/`.
6. Install Docker.

   - For Mac, you can use Docker Desktop if you meet the criteria of their free-use license restrictions or you pay for a license but you can also use [Colima](https://github.com/abiosoft/colima), [Podman](https://podman.io/getting-started/installation#macos) or Kubernetes installations like Minikube that expose the Docker Daemon directly.
   - For Linux, follow [the instructions here](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository).
   - When done, run `docker pull ubuntu:latest` (or some other image) just to confirm Docker is working.

7. Grab the scripts used in this article. `git clone https://github.com/dmikusa-pivotal/paketo-arm64`.

## Build `pack` CLI

If you are on Mac M1 hardware, you can download an official build from [the releases page](https://github.com/buildpacks/pack/releases). There are no official builds for ARM64 Linux at the moment, this may change in the future. For ARM64 on Linux, you need to build your own version. Follow these instructions to do that.

1. `git clone https://github.com/buildpacks/pack` && `git checkout v0.23.0` (change to latest release version tag at the time of building)
2. `cd pack && PACK_VERSION=0.23.0 make build`
3. `./out/pack version` to confirm the version
4. (Optional) Copy `./out/pack` to `/usr/local/bin/`

## Create a Stack

Basically [follow the stack creation instructions here](https://buildpacks.io/docs/operator-guide/create-a-stack/).

The instructions below are customized to use `ubuntu:focal` as the base image. You can use other base images, but you need to ensure there is a compatile ARM64 image available. For example, you cannot use `paketobuildpacks/build` or `paketobuildpacks/run` because these do not have ARM64 images at the moment. When Paketo is publishing ARM64 images for it's build/run images, you can skip this step and use them directly.

In the meantime:

1. Get a base image, `sudo docker pull ubuntu:focal`
2. `cd paketo-arm64/stack`
3. Customize the `Dockerfile`

You can customize the creation of the image in any way you need, for example if you need to add additional packages or tools to the build or run images. Just be aware that with the run image, whatever you add will end up in the final images used by application images you build.

When you're ready, build the images:

1. Build the run image: `sudo docker build . -t dmikusa2pivotal/stack-run:focal --target run --build-arg STACK_ID="<your-stack-id>"`
2. Build the build image: `sudo docker build . -t dmikusa2pivotal/stack-build:focal --target build --build-arg STACK_ID="<your-stack-id>"`

Your stack id can be anything, it just needs to be consistent across both images, and you also need to pass the value into the script when you create the builder below.

Congrats! You now have stack images.

## Package your Buildpacks

Next we need to build and package all of the buildpacks, with a few modifications. This is a tedious process, so I'm including some scripts to make it easier. There is still a little bit of manual work required, but it's a lot simpler with the scripts.

Here's the general process that is mostly automated by the scripts:

1. Clone and checkout all of the buildpacks we need.
2. Update buildpack.toml and package.toml to have unique ids [1].
3. Update any dependencies that are architecture specific to reference arm64 downloads. For Java, this is fortunately a small list: bellsoft-liberica, syft, and watchexec. [2]
4. Build the buildpacks. This includes the changes above and compiles arm64 binaries for build and detect.
5. Package the buildpacks into arm64 images.

[1] The current suite of packaging tools do not support manifest images, so you need to tag your images as `-arm64` or something to differenitate them from the standard buildpack images which are x86.
[2] This is a manual step.

Here are updated buildpack.toml files at the time of writing. You will need to manually check if there are newer versions of dependencies and update the buildpack.toml entries accordingly to ensure you have the latest dependencies.

1. [bellsoft-liberica](https://github.com/dmikusa-pivotal/paketo-arm64/blob/main/arm64-toml/bellsoft.toml)
2. [syft](https://github.com/dmikusa-pivotal/paketo-arm64/blob/main/syft.toml)
3. [watchexec](https://github.com/dmikusa-pivotal/paketo-arm64/blob/main/watchexec.toml)

The means the steps to execute are as follows:

1. `./scripts/clone.sh <buildpack-id> <buildpack-version>`
2. `find ./buildpacks  -name "buildpack.toml" | xargs -n 1 ./scripts/mod-bptoml.sh`
3. `find ./buildpacks  -name "package.toml" | xargs -n 1 ./scripts/mod-bptoml.sh`
4. Copy the `buildpack.toml` files for the three buildpacks referenced above from `paketo-arm64/arm64-toml`. Overwrite the `buildpack.toml` file in the project folder under the working directory with each.
5. `./scripts/build.sh <buildpack-id>`

At this point, you should have images. Run `docker images` to see what's there.

If you want to start over run `./scripts/reset.sh <buildpack-id> <buildpack-version>` or re-run the first step. The reset script will be slightly faster as it doesn't need to redownload everything.

## Create a Builder

Once you have buildpack images, it's time to build an builder image. There is a script for this as well. It'll generate a `builder.toml` file based on some input information and run `pack create builder` on that.

Run `create-builder.sh <buildpack-id> <buildpack-version> <lifecycle-version> <run-img> <build-img> <stack-id> <builder-id>`

The required information is as follows:

- The composite buildpack id
- The composite buildpack version
- A lifecycle version to use, whatever is latest often works best
- Your custom run image from above
- Your custom build build image from above
- The stack id you used when creating the stack above
- The name of your builder image

At this point, you should have a builder with all of your buildpacks. Time to build some apps!

## Build Samples

1. `git clone https://github.com/paketo-buildpacks/samples`
2. Install Java
3. `cd samples/java/maven`
4. `./mvnw package`
5. `sudo ~/pack/out/pack build apps/maven -p target/demo-0.0.1-SNAPSHOT.jar -B docker.io/dmikusa2pivotal/builder:focal --trust-builder`

It should now build & package up the app as an image.

## Troubleshooting

- `pack` not found. This can happen if you modify `$PATH` as some scripts use `sudo` but `sudo` won't inherit your custom `$PATH` by default. It's easier to put the required binaries into the `/usr/local/bin` directory or symlink them.

- If `create-builder.sh` fails, look at `buildpacks/builder/builder.toml`. This is the file that is generated. Review the input data to make sure you've entered the proper information. Often when it fails, it's because the information is not consistent across the buildpacks and builder metadata.

- There may be some issues running on Mac OS. This was tested on ARM64 Linux. For example, the script assumes you need to `sudo` when interacting with the Docker Daemon, which is not true on Mac OS. Open an issue or submit a PR if anything comes up.

## Details on the Automation Scripts

Here is a breakdown of the scripts that you can use to mostly automate this process. If you just want to build, you can probably skip this section. It just provides more information for those that are curious.

1. [clone.sh](https://github.com/dmikusa-pivotal/paketo-arm64/blob/main/scripts/clone.sh) can be used to quickly clone all of the buildpack repositories. It requires the buildpack id and version of a composite buildpack (buildpack that references other buildpacks). It will then go and clone all of the component (referenced buildpacks) and check out the version of those buildpacks set in the composite buildpack.

    For example: `./clone.sh paketo-buildpacks/java 6.4.0`. Will clone all of the referenced component buildpacks & the composite buildpack to the working directory (`./buildpacks`).

2. [mod-bptoml.sh](https://github.com/dmikusa-pivotal/paketo-arm64/blob/main/scripts/mod-bptoml.sh) can be used to quickly change the buildpack id of all the buildpacks. It will go through and append `-arm64` to the end of each buildpack id. This is useful so that there is something to differentiate between the images you're creating and standard x86 images.

    For example: `find ./buildpacks  -name "buildpack.toml" | xargs -n 1 ./mod-bptoml.sh`. This will find all of the buildpack.toml files in the working directory and update them.

3. [mod-pkgtoml.sh](https://github.com/dmikusa-pivotal/paketo-arm64/blob/main/scripts/mod-pkgtoml.sh) can be used to quickly change the image name of all the buildpacks. It will go through and append `-arm64` to the end of each image name. This is useful so that there is something to differentiate between the images you're creating and standard x86 images.

    For example: `find ./buildpacks  -name "buildpack.toml" | xargs -n 1 ./mod-bptoml.sh`. This will find all of the buildpack.toml files in the working directory and update them.

4. [build.sh](https://github.com/dmikusa-pivotal/paketo-arm64/blob/main/scripts/build.sh) can be used to iterate over all of the buildpacks in the working directory (created by `clone.sh`).

    For example: `./build.sh paketo-buildpacks/java`.

5. [reset.sh](https://github.com/dmikusa-pivotal/paketo-arm64/blob/main/scripts/reset.sh) can be used to reset the temporary directory to a given working state. You pass it the composite buildpack id and version. It will reset, pull and check out that version. Then recursively do the same for all referenced buildpacks.

    For example: `./reset.sh paketo-buildpacks/java 6.4.0`. This will reset the working directory to the 6.4.0 version. If this fails, like if new buildpacks have been introduced, then you should run `clone.sh` instead. Running `clone.sh` is similar but wipes and results in a fresh working directory.

6. [create-builder.sh](https://github.com/dmikusa-pivotal/paketo-arm64/blob/main/create-builder.sh) can be used to generate a `builder.toml` and create a builder image. This works by generating a builder.toml based on the information passed into it and what's in the referenced composite buildpack's `buildpack.toml` file. This requires a lot of input so see [this section](#create-a-builder) for details on running it.
