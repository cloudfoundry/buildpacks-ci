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

RUN curl -sL "https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key" | apt-key add - \
  && echo "deb https://packages.cloudfoundry.org/debian stable main" | tee /etc/apt/sources.list.d/cloudfoundry-cli.list

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
  cf-cli \
  vim \
  wget \
  zip \
  google-chrome-stable && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install packages that are specific to ubuntu and not debian
# Including libssl allows us to build php on this image
RUN wget http://cdn-fastly.deb.debian.org/debian/pool/main/i/icu/libicu52_52.1-8+deb8u7_amd64.deb \
  && dpkg -i libicu52_52.1-8+deb8u7_amd64.deb \
  && rm libicu52_52.1-8+deb8u7_amd64.deb \
  && wget http://mirror.nus.edu.sg/Debian/pool/main/o/openssl/libssl1.0.0_1.0.1t-1%2Bdeb8u8_amd64.deb   \
  && dpkg -i libssl1.0.0_1.0.1t-1+deb8u8_amd64.deb \
	&& rm libssl1.0.0_1.0.1t-1+deb8u8_amd64.deb

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

# download the bosh2 CLI
RUN curl -L https://github.com/cloudfoundry/bosh-cli/releases/download/v5.5.1/bosh-cli-5.5.1-linux-amd64 -o /usr/local/bin/bosh2 \
  && [ 34e9898c244655ccbce2dc657b7d1df52e487cfd = $(shasum -a 1 /usr/local/bin/bosh2 | cut -d' ' -f1) ] \
  && chmod +x /usr/local/bin/bosh2 \
  && ln -s /usr/local/bin/bosh2 /usr/local/bin/bosh

# download bbl
RUN wget -O /usr/local/bin/bbl 'https://github.com/cloudfoundry/bosh-bootloader/releases/download/v7.6.0/bbl-v7.6.0_linux_x86-64' \
  && [ 2e81f0560310791d604145b39f0b0c21cfd50d2c314fcd58059ff7a006cf12ca = $(shasum -a 256 /usr/local/bin/bbl | cut -d' ' -f1) ] \
  && chmod +x /usr/local/bin/bbl

# download credhub cli
RUN curl -L https://github.com/cloudfoundry-incubator/credhub-cli/releases/download/2.4.0/credhub-linux-2.4.0.tgz -o credhub.tgz \
  && [ 73edaf1ee47323c4f0aa455bcc17303a73c0cf2a6d9156542f1f6b7b1b1aa3db = $(shasum -a 256 credhub.tgz | cut -d' ' -f1) ] \
  && tar -zxf credhub.tgz --to-stdout > /usr/local/bin/credhub \
  && rm credhub.tgz \
  && chmod +x /usr/local/bin/credhub


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
  && gem install bundler -v 2.0.1
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

# Install go 1.12
RUN cd /usr/local \
  && curl -L https://dl.google.com/go/go1.12.4.linux-amd64.tar.gz -o go.tar.gz \
  && [ d7d1f1f88ddfe55840712dc1747f37a790cbcaa448f6c9cf51bbe10aa65442f5 = $(shasum -a 256 go.tar.gz | cut -d' ' -f1) ] \
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
