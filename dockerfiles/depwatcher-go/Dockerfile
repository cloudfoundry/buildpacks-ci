FROM golang:1.24 AS builder

ADD . /src
WORKDIR /src
RUN go mod tidy
RUN CGO_ENABLED=0 go build -o /opt/resource/check ./cmd/check
RUN CGO_ENABLED=0 go build -o /opt/resource/in ./cmd/in

FROM ubuntu:noble

RUN \
  apt-get update && \
  apt-get install -y ca-certificates curl jq && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=builder /opt/resource/check /opt/resource/check
COPY --from=builder /opt/resource/in /opt/resource/in
