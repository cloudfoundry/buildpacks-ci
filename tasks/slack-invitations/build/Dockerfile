FROM alpine:latest

RUN apk add --no-progress --no-cache curl

ARG GO_VERSION=1.14
RUN curl \
  https://dl.google.com/go/go$GO_VERSION.linux-amd64.tar.gz \
    --silent \
    --location \
    --output /tmp/go$GO_VERSION.linux-amd64.tar.gz \
  && tar -C /usr/local -xzf /tmp/go$GO_VERSION.linux-amd64.tar.gz \
  && rm /tmp/go$GO_VERSION.linux-amd64.tar.gz \
  && mkdir /lib64 && ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2

ENV PATH=$PATH:/usr/local/go/bin

COPY * /tmp/

RUN go build -o /usr/local/bin/slack-invitations /tmp/main.go

CMD slack-invitations
