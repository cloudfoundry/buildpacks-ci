FROM ruby:2.3.1-slim

ENV LANG="C.UTF-8"

RUN apt-get update
RUN apt-get -y install \
  awscli \
  aufs-tools \
  curl \
  expect \
  git \
  iptables \
  libmysqlclient-dev \
  libpq-dev \
  libsqlite3-dev \
  module-init-tools \
  npm \
  php5 \
  python-dev \
  python-pip \
  shellcheck \
  wget \
  zip

RUN curl -sSL https://get.docker.com/ | sh

RUN git config --global user.email "cf-buildpacks-eng@pivotal.io"
RUN git config --global user.name "CF Buildpacks Team CI Server"
RUN git config --global core.pager cat

RUN wget -q https://releases.hashicorp.com/vagrant/1.8.5/vagrant_1.8.5_x86_64.deb \
  && dpkg -i vagrant_1.8.5_x86_64.deb \
  && rm vagrant_1.8.5_x86_64.deb
RUN vagrant plugin install vagrant-aws --verbose
ENV PATH /usr/bin:$PATH
RUN echo $PATH && vagrant box add cloudfoundry/bosh-lite --provider aws

# composer is a package manager for PHP apps
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/
RUN mv /usr/bin/composer.phar /usr/bin/composer

# download the CF-CLI
RUN wget -O- 'https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.22.2&source=github-rel'| tar xz -C /usr/bin
RUN cf install-plugin Diego-Enabler -f -r CF-Community

#download spiff for spiffy things
RUN wget -O- 'https://github.com/cloudfoundry-incubator/spiff/releases/download/v1.0.7/spiff_linux_amd64.zip' | funzip > /usr/bin/spiff
RUN chmod 755 /usr/bin/spiff

#download hub CLI
RUN wget -O- https://github.com/github/hub/releases/download/v2.2.1/hub-linux-amd64-2.2.1.tar.gz | tar xz -C /usr/bin --strip-components=1 hub-linux-amd64-2.2.1/hub

# Ensure Concourse Filter binary is present
RUN wget 'https://github.com/pivotal-cf-experimental/concourse-filter/releases/download/v0.0.2/concourse-filter' && mv concourse-filter /usr/local/bin && chmod +x /usr/local/bin/concourse-filter

# when docker container starts, ensure login scripts run
COPY build/*.sh /etc/profile.d/

# install buildpacks-ci Gemfile
RUN gem install bundler
COPY Gemfile /usr/local/Gemfile
RUN cd /usr/local && bundle install

#install fly-cli
RUN curl "https://buildpacks.ci.cf-app.com/api/v1/cli?arch=amd64&platform=linux" -sfL -o /usr/local/bin/fly
RUN chmod +x /usr/local/bin/fly

# git-hooks and git-secrets
RUN curl -L https://github.com/git-hooks/git-hooks/releases/download/v1.1.3/git-hooks_linux_amd64.tar.gz | tar -zxf - --to-stdout > /usr/local/bin/git-hooks
RUN chmod 755 /usr/local/bin/git-hooks
RUN git clone https://github.com/awslabs/git-secrets && cd git-secrets && make install

# Ensure that Concourse filtering is on for non-interactive shells
ENV BASH_ENV /etc/profile.d/filter.sh

# Install go 1.6.2
RUN cd /usr/local && curl -L https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz -o go.tar.gz && tar xf go.tar.gz && mv go/bin/go /usr/local/bin/go
