FROM alpine:latest

RUN apk add --no-progress --no-cache \
  tzdata \
  curl \
  zip

ARG DELEGATEBOT_VERSION=0.11.0
RUN curl \
  https://github.com/dpb587/slack-delegate-bot/releases/download/v$DELEGATEBOT_VERSION/slack-delegate-bot-linux.zip \
    --silent \
    --location \
    --output /tmp/delegatebot.zip \
  && unzip /tmp/delegatebot.zip slack-delegate-bot \
  && mv slack-delegate-bot /bin/delegatebot \
  && chmod +x /bin/delegatebot \
  && rm /tmp/delegatebot.zip

COPY config.yml /etc/config.yml

CMD delegatebot --config /etc/config.yml run
