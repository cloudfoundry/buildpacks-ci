FROM crystallang/crystal:1.17.0

ADD . /src
WORKDIR /src
RUN shards install
RUN shards build --production

FROM ubuntu:bionic

RUN \
  apt-get update && \
  apt-get install -y apt-transport-https libxml2-dev libevent-2.1-6 libyaml-dev ca-certificates curl jq && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=0 /src/bin/check /opt/resource/check
COPY --from=0 /src/bin/in /opt/resource/in
