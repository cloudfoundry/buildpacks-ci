FROM crystallang/crystal:latest

ADD . /src
WORKDIR /src
RUN shards && crystal spec --no-debug
RUN shards build --production

FROM ubuntu:xenial

RUN \
  apt-get update && \
  apt-get install -y apt-transport-https libxml2-dev libevent-2.0-5 && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=0 /src/bin/check /opt/resource/check
COPY --from=0 /src/bin/in /opt/resource/in
