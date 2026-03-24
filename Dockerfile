FROM node:22-alpine

RUN apk add --no-cache git curl bash

WORKDIR /work
COPY run.sh /run.sh
COPY devcontainer.json /devcontainer.json
RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]