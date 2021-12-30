## For the Base image (both build & run)
FROM ubuntu:focal as base

ARG STACK_ID

ENV CNB_USER_ID=1000
ENV CNB_GROUP_ID=1000
ENV CNB_STACK_ID=${STACK_ID}
LABEL io.buildpacks.stack.id=${STACK_ID}

RUN groupadd cnb --gid ${CNB_GROUP_ID} && \
  useradd --uid ${CNB_USER_ID} --gid ${CNB_GROUP_ID} -m -s /bin/bash cnb

## For the Run Image

FROM base as run

ARG PKG_ARGS='--allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends'

# This comes from here: https://github.com/paketo-buildpacks/stacks/blob/main/bionic/dockerfile/run/Dockerfile and
#  the packages from here: https://github.com/paketo-buildpacks/stacks/blob/main/packages/base/run
#  which is what's used in paketobuildpacks/base:build image
RUN echo "debconf debconf/frontend select noninteractive" | debconf-set-selections && \
  export DEBIAN_FRONTEND=noninteractive && \
  apt-get -y ${PKG_ARGS} update && \
  apt-get -y ${PKG_ARGS} upgrade && \
  apt-get -y ${PKG_ARGS} install locales && \
  locale-gen en_US.UTF-8 && \
  update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8 && \
  apt-get install -y ca-certificates libssl1.1 libyaml-0-2 netbase openssl tzdata zlib1g && \
  find /usr/share/doc/*/* ! -name copyright | xargs rm -rf && \
  rm -rf \
  /usr/share/man/* /usr/share/info/* \
  /usr/share/groff/* /usr/share/lintian/* /usr/share/linda/* \
  /var/lib/apt/lists/* /tmp/*

USER ${CNB_USER_ID}:${CNB_GROUP_ID}

# For the Build Image

FROM base as build

# This comes from here: https://github.com/paketo-buildpacks/stacks/blob/main/bionic/dockerfile/build/Dockerfile and
#  the packages from here: https://github.com/paketo-buildpacks/stacks/blob/main/packages/base/build
#  which is what's used in paketobuildpacks/base:build image
RUN echo "debconf debconf/frontend select noninteractive" | debconf-set-selections && \
  export DEBIAN_FRONTEND=noninteractive && \
  apt-get -y ${PKG_ARGS} update && \
  apt-get -y ${PKG_ARGS} upgrade && \
  apt-get -y ${PKG_ARGS} install locales && \
  locale-gen en_US.UTF-8 && \
  update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8 && \
  apt-get -y ${PKG_ARGS} install build-essential ca-certificates curl git jq libgmp-dev libssl1.1 libyaml-0-2 netbase openssl tzdata xz-utils zlib1g-dev && \
  rm -rf /var/lib/apt/lists/* /tmp/*

RUN curl -sL -o /usr/local/bin/yj https://github.com/sclevine/yj/releases/latest/download/yj-linux \
  && chmod +x /usr/local/bin/yj

USER ${CNB_USER_ID}:${CNB_GROUP_ID}
