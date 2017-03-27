FROM ruby:slim

RUN gem install parse-cron activesupport

# Copy in resources
ENV TMPDIR /tmp
RUN mkdir -p /opt/resource/
COPY check in /opt/resource/

