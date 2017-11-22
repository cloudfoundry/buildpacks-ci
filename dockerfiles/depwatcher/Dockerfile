FROM crystallang/crystal:0.23.1

ADD . /src
WORKDIR /src
RUN shards build --production
# RUN crystal run ./support/list-deps.cr -- ./bin/check

FROM ubuntu:xenial

RUN \
  apt-get update && \
  apt-get install -y apt-transport-https && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=0 /src/bin/check /opt/resource/check
COPY --from=0 /src/bin/in /opt/resource/in
