FROM ruby:2.3.1-slim

ENV LANG="C.UTF-8"

COPY config/apt-key.gpg /tmp/apt-key.gpg
RUN echo "deb http://packages.cloud.google.com/apt cloud-sdk-jessie main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
  && apt-key add /tmp/apt-key.gpg

RUN apt-get update \
  && apt-get -y install \
  aufs-tools \
  curl \
  expect \
  git \
  google-cloud-sdk \
  iptables \
  jq \
  libmysqlclient-dev \
  libpq-dev \
  libsqlite3-dev \
  lsb-release \
  module-init-tools \
  npm \
  php5 \
  python-dev \
  python-pip \
  shellcheck \
  wget \
  zip && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sSL https://get.docker.com/ | sh

RUN git config --global user.email "cf-ci-bot@suse.de"
RUN git config --global user.name "SUSE CF CI Bot"
RUN git config --global core.pager cat

RUN wget -q https://releases.hashicorp.com/vagrant/1.8.5/vagrant_1.8.5_x86_64.deb \
  && [ 30ee435c3358c6a835ea52cf710f4e50caa0e77cb721332132a2d3386a8745d9 = $(shasum -a 256 vagrant_1.8.5_x86_64.deb | cut -d' ' -f1) ]\
  && dpkg -i vagrant_1.8.5_x86_64.deb \
  && rm vagrant_1.8.5_x86_64.deb
RUN vagrant plugin install vagrant-aws --verbose
ENV PATH /usr/bin:$PATH
RUN echo $PATH && vagrant box add cloudfoundry/bosh-lite --provider aws

# composer is a package manager for PHP apps
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/
RUN mv /usr/bin/composer.phar /usr/bin/composer

# download the CF-CLI
RUN wget -O cf-cli.tgz 'https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.33.0&source=github-rel' \
  && [ 443b61459bed73571e987f5c09ac559278da68fffa62ebe521d770d00b8f5629 = $(shasum -a 256 cf-cli.tgz | cut -d' ' -f1) ] \
  && tar xzf cf-cli.tgz -C /usr/bin \
  && rm cf-cli.tgz

# download the bosh2 CLI
RUN curl https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-2.0.45-linux-amd64 -o /usr/local/bin/bosh2 \
  && [ bf04be72daa7da0c9bbeda16fda7fc7b2b8af51e = $(shasum -a 1 /usr/local/bin/bosh2 | cut -d' ' -f1) ] \
  && chmod +x /usr/local/bin/bosh2

# download bbl
RUN wget -O /usr/local/bin/bbl 'https://github.com/cloudfoundry/bosh-bootloader/releases/download/v4.10.5/bbl-v4.10.5_linux_x86-64' \
  && [ 3a782b9be10c93120f7b0d10e68704e299b79c836168a3538384ec31f69fc9d0 = $(shasum -a 256 /usr/local/bin/bbl | cut -d' ' -f1) ] \
  && chmod +x /usr/local/bin/bbl

# download terraform (used by bbl)
RUN wget -O terraform.zip 'https://releases.hashicorp.com/terraform/0.10.8/terraform_0.10.8_linux_amd64.zip' \
  && [ b786c0cf936e24145fad632efd0fe48c831558cc9e43c071fffd93f35e3150db = $(shasum -a 256 terraform.zip | cut -d' ' -f1) ] \
  && funzip terraform.zip > /usr/local/bin/terraform \
  && rm terraform.zip \
  && chmod 755 /usr/local/bin/terraform

#download spiff for spiffy things
RUN wget -O spiff.zip 'https://github.com/cloudfoundry-incubator/spiff/releases/download/v1.0.8/spiff_linux_amd64.zip' \
  && [ e5b49b7f32b2b3973536bf2a48beda2d236956bebff7677aa109cc2b71f56002 = $(shasum -a 256 spiff.zip | cut -d' ' -f1) ] \
  && funzip spiff.zip > /usr/bin/spiff \
  && rm spiff.zip
RUN chmod 755 /usr/bin/spiff

# Ensure Concourse Filter binary is present
RUN wget 'https://github.com/pivotal-cf-experimental/concourse-filter/releases/download/v0.0.3/concourse-filter' \
  && [ 78dde97f155a73439834261dd7dce3f622c1aba79c487d8bc4d187ac3f4f407a = $(shasum -a 256 concourse-filter | cut -d' ' -f1) ] \
  && mv concourse-filter /usr/local/bin \
  && chmod +x /usr/local/bin/concourse-filter

# AWS CLI
RUN pip install awscli

# when docker container starts, ensure login scripts run
COPY build/*.sh /etc/profile.d/

# install buildpacks-ci Gemfile
RUN gem update --system
RUN gem install bundler -v 1.15.4
COPY Gemfile /usr/local/Gemfile
COPY Gemfile.lock /usr/local/Gemfile.lock
RUN cd /usr/local && bundle install
RUN bundle binstub bundler --force

#install fly-cli
RUN curl "https://buildpacks.ci.cf-app.com/api/v1/cli?arch=amd64&platform=linux" -sfL -o /usr/local/bin/fly \
  && chmod +x /usr/local/bin/fly

# git-hooks and git-secrets
RUN curl -L https://github.com/git-hooks/git-hooks/releases/download/v1.1.4/git-hooks_linux_amd64.tar.gz -o githooks.tgz \
  && [ 3f21c856064f8f08f8c25494ac784882a2b8811eea3bfb721a6c595b55577c48 = $(shasum -a 256 githooks.tgz | cut -d' ' -f1) ] \
  && tar -zxf githooks.tgz --to-stdout > /usr/local/bin/git-hooks \
  && rm githooks.tgz \
  && chmod 755 /usr/local/bin/git-hooks

RUN git clone https://github.com/awslabs/git-secrets && cd git-secrets && make install

# Ensure that Concourse filtering is on for non-interactive shells
ENV BASH_ENV /etc/profile.d/filter.sh

# Install go 1.9
RUN cd /usr/local \
  && curl -L https://buildpacks.cloudfoundry.org/dependencies/go/go1.9.2.linux-amd64-f60fe671.tar.gz -o go.tar.gz \
  && [ 6af27e6a59b4538fbf196c8019ef67c5cfeb6d21298bf9bb6bab1390a4da3448 = $(shasum -a 256 go.tar.gz | cut -d' ' -f1) ] \
  && tar xf go.tar.gz \
  && rm go.tar.gz \
  && ln -s /usr/local/go/bin/* /usr/local/bin/

ENV GOROOT=/usr/local/go

# Install poltergeist for running dotnet-core-buildpack specs
RUN gem install phantomjs && ruby -e 'require "phantomjs"; Phantomjs.path'

# Add git known host
RUN mkdir -p /root/.ssh/ && echo github.com,192.30.252.131 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ== > /root/.ssh/known_hosts
