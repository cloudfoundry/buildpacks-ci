FROM ruby:2.1.5-slim

RUN apt-get update
RUN apt-get -y install \
  git \
  libsqlite3-dev \
  npm \
  vagrant \
  wget \
  zip

RUN vagrant plugin install vagrant-aws
RUN vagrant box add cloudfoundry/bosh-lite --provider aws

RUN wget -O- 'https://cli.run.pivotal.io/stable?release=linux64-binary&source=github'| tar xz -C /usr/bin
COPY build/ssh-agent.sh /etc/profile.d/
COPY build/ruby.sh /etc/profile.d/
