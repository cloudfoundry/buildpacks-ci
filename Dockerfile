FROM ruby:2.1.5

RUN apt-get update
RUN apt-get -y install \
  npm \
  vagrant \
  zip

RUN vagrant plugin install vagrant-aws
RUN vagrant box add cloudfoundry/bosh-lite --provider aws

RUN wget -O- 'https://cli.run.pivotal.io/stable?release=linux64-binary&source=github'| tar xz -C /usr/bin
