FROM ruby:2.3.1-slim

ENV LANG="C.UTF-8"

RUN apt-get update
RUN apt-get -y install \
  aufs-tools \
  curl \
  expect \
  git \
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
  zip

RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
  && echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
  && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
  && apt-get update \
  && apt-get -y install google-cloud-sdk

RUN curl -sSL https://get.docker.com/ | sh

RUN git config --global user.email "cf-buildpacks-eng@pivotal.io"
RUN git config --global user.name "CF Buildpacks Team CI Server"
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
RUN wget -O cf-cli.tgz 'https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.32.0&source=github-rel' \
  && [ 0a05521b7198dc8b92efbfb02a8fb04c84eeffeded3387aa3c9eb92ce4abef69 = $(shasum -a 256 cf-cli.tgz | cut -d' ' -f1) ] \
  && tar xzf cf-cli.tgz -C /usr/bin \
  && rm cf-cli.tgz
RUN cf install-plugin Diego-Enabler -f -r CF-Community

# download the bosh2 CLI
RUN curl https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-2.0.42-linux-amd64 -o /usr/local/bin/bosh2 \
  && [ a97b085e45a989abfcd88de77770bb6db0c8a29e = $(shasum -a 1 /usr/local/bin/bosh2 | cut -d' ' -f1) ] \
  && chmod +x /usr/local/bin/bosh2

# download bbl
RUN wget -O /usr/local/bin/bbl 'https://github.com/cloudfoundry/bosh-bootloader/releases/download/v4.10.4/bbl-v4.10.4_linux_x86-64' \
  && [ c1d2c001250506bd312203839058baf11ad7f53e150c8a6a1ff617a86d39f21a = $(shasum -a 256 /usr/local/bin/bbl | cut -d' ' -f1) ] \
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

#download hub CLI
RUN wget -O hub.tgz https://github.com/github/hub/releases/download/v2.2.1/hub-linux-amd64-2.2.1.tar.gz \
  && [ c6131dcad312c314929e800c36c925b78ade84ee91fcc67a2a41cde40e22a5c2 = $(shasum -a 256 hub.tgz | cut -d' ' -f1) ] \
  && tar xzf hub.tgz -C /usr/bin --strip-components=1 hub-linux-amd64-2.2.1/hub \
  && rm hub.tgz

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

#install fly-cli
RUN curl "https://buildpacks.ci.cf-app.com/api/v1/cli?arch=amd64&platform=linux" -sfL -o /usr/local/bin/fly \
  && [ 8638c75c3294c104da75526cab827d1b61c8ab2c05bb999340214cade37a7516 = $(shasum -a 256 /usr/local/bin/fly | cut -d' ' -f1) ] \
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
  && curl -L https://buildpacks.cloudfoundry.org/dependencies/go/go1.9.linux-amd64-4577d9ba.tar.gz -o go.tar.gz \
  && [ d3a0193410b9b62251aa12b49780dcea3ccfd10402b05685e54051c9c0b89e72 = $(shasum -a 256 go.tar.gz | cut -d' ' -f1) ] \
  && tar xf go.tar.gz \
  && rm go.tar.gz \
  && ln -s /usr/local/go/bin/* /usr/local/bin/

ENV GOROOT=/usr/local/go

#download certstrap to strap certs
RUN git clone https://github.com/square/certstrap \
  && cd certstrap \
  && ./build \
  && install bin/certstrap-*-linux-amd64 /usr/local/bin/certstrap

# Install poltergeist for running dotnet-core-buildpack specs
RUN gem install phantomjs && ruby -e 'require "phantomjs"; Phantomjs.path'

# Add git known host
RUN mkdir -p /root/.ssh/ && echo github.com,192.30.252.131 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ== > /root/.ssh/known_hosts
