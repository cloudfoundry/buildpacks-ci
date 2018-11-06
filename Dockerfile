FROM ruby:2.3-slim

ENV LANG="C.UTF-8"

RUN apt-get update && apt-get install -y curl gnupg apt-transport-https

COPY config/google-chrome-apt-key.pub /tmp/
RUN echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
  && apt-key add /tmp/google-chrome-apt-key.pub

RUN echo "deb http://packages.cloud.google.com/apt cloud-sdk-jessie main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
  && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

RUN curl -sL "https://keybase.io/crystal/pgp_keys.asc" | apt-key add - \
    && echo "deb https://dist.crystal-lang.org/apt crystal main" | tee /etc/apt/sources.list.d/crystal.list

RUN apt-get update \
  && apt-get -y install \
  aufs-tools \
  crystal \
  libxml2-dev \
  expect \
  git \
  google-cloud-sdk \
  iptables \
  jq \
  default-libmysqlclient-dev \
  libpq-dev \
  libsqlite3-dev \
  libgconf-2-4 \
  lsb-release \
  php7.0 \
  pkgconf \
  python-dev \
  python-pip \
  shellcheck \
  vim \
  wget \
  zip \
  google-chrome-stable && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sSL https://get.docker.com/ | sh

RUN git config --global user.email "cf-buildpacks-eng@pivotal.io"
RUN git config --global user.name "CF Buildpacks Team CI Server"
RUN git config --global core.pager cat

# download and install chromedriver
 RUN wget -O chromedriver.zip 'https://chromedriver.storage.googleapis.com/2.34/chromedriver_linux64.zip' \
   && [ e42a55f9e28c3b545ef7c7727a2b4218c37489b4282e88903e4470e92bc1d967 = $(shasum -a 256 chromedriver.zip | cut -d' ' -f1) ] \
   && unzip chromedriver.zip -d /usr/local/bin/ \
   && rm chromedriver.zip

# composer is a package manager for PHP apps
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/
RUN mv /usr/bin/composer.phar /usr/bin/composer

# download the CF-CLI
RUN wget -O cf-cli.tgz 'https://packages.cloudfoundry.org/stable?release=linux64-binary&version=6.40.0&source=github-rel' \
  && [ de34bb9755ec9f9ca9605b14c690a9013157cc3c83fc647beb2c842a03c8b5b2 = $(shasum -a 256 cf-cli.tgz | cut -d' ' -f1) ] \
  && tar xzf cf-cli.tgz -C /usr/bin \
  && rm cf-cli.tgz \
  && cf install-plugin -r CF-Community "log-cache" -f

# download the bosh2 CLI
RUN curl https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-2.0.45-linux-amd64 -o /usr/local/bin/bosh2 \
  && [ bf04be72daa7da0c9bbeda16fda7fc7b2b8af51e = $(shasum -a 1 /usr/local/bin/bosh2 | cut -d' ' -f1) ] \
  && chmod +x /usr/local/bin/bosh2 \
  && ln -s /usr/local/bin/bosh2 /usr/local/bin/bosh

# download bbl
RUN wget -O /usr/local/bin/bbl 'https://github.com/cloudfoundry/bosh-bootloader/releases/download/v6.10.18/bbl-v6.10.18_linux_x86-64' \
  && [ adeccd88a9d3ac370983c8aea20f989bdca8c53c2aa08521c1ed8c5b2a3b0ad0 = $(shasum -a 256 /usr/local/bin/bbl | cut -d' ' -f1) ] \
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
RUN wget 'https://github.com/pivotal-cf-experimental/concourse-filter/releases/download/v0.0.4/concourse-filter' \
  && [ 2bcad41417bf5bdc545a0912c30d9c466abd4ed0cffa6b02b678f06f71a73bb8 = $(shasum -a 256 concourse-filter | cut -d' ' -f1) ] \
  && mv concourse-filter /usr/local/bin \
  && chmod +x /usr/local/bin/concourse-filter

# AWS CLI
RUN pip install awscli

# when docker container starts, ensure login scripts run
COPY build/*.sh /etc/profile.d/

# install buildpacks-ci Gemfile
RUN gem update --system \
  && gem install bundler -v 1.15.4
COPY Gemfile /usr/local/Gemfile
COPY Gemfile.lock /usr/local/Gemfile.lock
RUN cd /usr/local && bundle install && bundle binstub bundler --force

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

# Install go 1.11
RUN cd /usr/local \
  && curl -L https://dl.google.com/go/go1.11.linux-amd64.tar.gz -o go.tar.gz \
  && [ b3fcf280ff86558e0559e185b601c9eade0fd24c900b4c63cd14d1d38613e499 = $(shasum -a 256 go.tar.gz | cut -d' ' -f1) ] \
  && tar xf go.tar.gz \
  && rm go.tar.gz \
  && ln -s /usr/local/go/bin/* /usr/local/bin/

ENV GOROOT=/usr/local/go

# Install gems
# poltergeist for running dotnet-core-buildpack specs
RUN gem install phantomjs open4 \
  && ruby -e 'require "phantomjs"; Phantomjs.path'

# Add git known host
RUN mkdir -p /root/.ssh/ && echo github.com,192.30.252.131 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ== > /root/.ssh/known_hosts
