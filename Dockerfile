FROM ruby:2.1.5-slim

ENV LANG="C.UTF-8"

RUN apt-get update
RUN apt-get -y install \
  awscli \
  git \
  golang \
  libpq-dev \
  libsqlite3-dev \
  npm \
  php5 \
  python-dev \
  python-pip \
  vagrant \
  wget \
  zip

RUN vagrant plugin install vagrant-aws
RUN vagrant box add cloudfoundry/bosh-lite --provider aws

# godep is a package manager for golang apps
RUN GOPATH=/go go get github.com/tools/godep

# composer is a package manager for PHP apps
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/
RUN mv /usr/bin/composer.phar /usr/bin/composer

# download the CF-CLI
RUN wget -O- 'https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.10.0&source=github-rel'| tar xz -C /usr/bin

# when docker container starts, ensure login scripts run
COPY build/ssh-agent.sh /etc/profile.d/
COPY build/ruby.sh /etc/profile.d/
COPY build/go.sh /etc/profile.d/
