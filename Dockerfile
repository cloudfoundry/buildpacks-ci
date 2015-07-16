FROM ruby:2.2.2-slim

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
RUN wget -O- 'https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.12.0&source=github-rel'| tar xz -C /usr/bin
RUN cf install-plugin https://github.com/cloudfoundry-incubator/diego-cli-plugin/raw/master/bin/linux64/diego-beta.linux64
RUN cf install-plugin https://github.com/cloudfoundry-incubator/diego-ssh/releases/download/plugin-0.1.2/ssh-plugin-linux-amd64

#download spiff for spiffy things
RUN wget -O- 'https://github.com/cloudfoundry-incubator/spiff/releases/download/v1.0.7/spiff_linux_amd64.zip' | funzip > /usr/bin/spiff
RUN chmod 755 /usr/bin/spiff

#download hub CLI
RUN wget -O- https://github.com/github/hub/releases/download/v2.2.1/hub-linux-amd64-2.2.1.tar.gz | tar xz -C /usr/bin --strip-components=1 hub-linux-amd64-2.2.1/hub

# when docker container starts, ensure login scripts run
COPY build/ssh-agent.sh /etc/profile.d/
COPY build/ruby.sh /etc/profile.d/
COPY build/go.sh /etc/profile.d/
