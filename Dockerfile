FROM node:22.30.0-alpine

RUN apk add --no-cache git curl bash

WORKDIR /work
COPY run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]