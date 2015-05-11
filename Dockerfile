FROM ruby:2.1.5-slim

ENV LANG="C.UTF-8"

RUN apt-get update
RUN apt-get -y install \
  git \
  golang \
  libpq-dev \
  libsqlite3-dev \
  npm \
  python-dev \
  vagrant \
  wget \
  zip

RUN vagrant plugin install vagrant-aws
RUN vagrant box add cloudfoundry/bosh-lite --provider aws

RUN GOPATH=/go go get github.com/tools/godep
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python get-pip.py

RUN wget -O- 'https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.10.0&source=github-rel'| tar xz -C /usr/bin
COPY build/ssh-agent.sh /etc/profile.d/
COPY build/ruby.sh /etc/profile.d/
COPY build/go.sh /etc/profile.d/
