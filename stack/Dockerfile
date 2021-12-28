## For the Base image (both build & run)
FROM ubuntu:focal as base
ARG STACK_ID

ENV CNB_USER_ID=1000
ENV CNB_GROUP_ID=1000
ENV CNB_STACK_ID=${STACK_ID}
LABEL io.buildpacks.stack.id=${STACK_ID}

RUN groupadd cnb --gid ${CNB_GROUP_ID} && \
  useradd --uid ${CNB_USER_ID} --gid ${CNB_GROUP_ID} -m -s /bin/bash cnb

RUN apt-get update && \
  apt-get install -y xz-utils ca-certificates && \
  rm -rf /var/lib/apt/lists/*

## For the Run Image

FROM base as run

USER ${CNB_USER_ID}:${CNB_GROUP_ID}

# For the Build Image

FROM base as build

RUN apt-get update && \
  apt-get install -y git wget jq && \
  rm -rf /var/lib/apt/lists/* && \
  wget https://github.com/sclevine/yj/releases/download/v5.0.0/yj-linux -O /usr/local/bin/yj && \
  chmod +x /usr/local/bin/yj

USER ${CNB_USER_ID}:${CNB_GROUP_ID}
