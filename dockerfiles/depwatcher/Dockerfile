FROM crystallang/crystal:0.23.1

ADD . /src
WORKDIR /src
RUN crystal spec
RUN shards build --production

FROM ubuntu:xenial

RUN \
  apt-get update && \
  apt-get install -y apt-transport-https libxml2-dev && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=0 /src/bin/check /opt/resource/check
COPY --from=0 /src/bin/in /opt/resource/in
