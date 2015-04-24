FROM ruby:2.1.5

RUN apt-get update
RUN apt-get -y install \
  npm \
  zip

RUN wget -O- 'https://cli.run.pivotal.io/stable?release=linux64-binary&source=github'| tar xz -C /usr/bin
