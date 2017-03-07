FROM alpine
RUN apk add --no-cache bash wget jq ca-certificates

# Copy in resources
ENV TMPDIR /tmp
RUN mkdir -p /opt/resource/
COPY check in out /opt/resource/

