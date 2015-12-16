FROM alpine

RUN apk add --update \
  ruby \
  git \
  ruby-json \
  ca-certificates

ADD /scripts /opt/resource
RUN chmod +x /opt/resource/*
