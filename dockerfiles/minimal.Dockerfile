FROM ubuntu:bionic

RUN \
  apt-get update && \
  apt-get -qqy install --fix-missing \
    build-essential \
    curl \
    gnupg \
    vim \
    git \
  && \
  apt-get clean

# install jq
ARG JQ_VERSION=1.6
RUN curl "https://github.com/stedolan/jq/releases/download/jq-$JQ_VERSION/jq-linux64" \
    --silent \
    --location \
    --output /usr/local/bin/jq \
  && chmod +x /usr/local/bin/jq
