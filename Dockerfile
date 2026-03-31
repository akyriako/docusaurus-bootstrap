FROM node:22-alpine

RUN apk add --no-cache git curl bash

WORKDIR /work

COPY run.sh /run.sh
COPY devcontainer.json /devcontainer.json
COPY docusaurus.dockerfile /docusaurus.dockerfile
COPY check.workflow.github /check.workflow.github
COPY build.workflow.github /build.workflow.github

COPY kustomize/ /kustomize

RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]