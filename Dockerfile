FROM ubuntu:jammy

ENV LANG="C.UTF-8"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -qqy update \
  && apt-get -qqy install \
    curl \
    gnupg \
  && apt-get -qqy clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Reevaluate if all of these are needed
RUN apt-get -qqy update \
  && apt-get -qqy install \
    ca-certificates \
    build-essential \
    btrfs-progs \
    default-libmysqlclient-dev \
    expect \
    git \
    google-cloud-sdk \
    iptables \
    jq \
    libssl-dev \
    zlib1g-dev \
    libreadline-dev \
    libncurses5-dev \
    libgdbm-dev \
    libdb-dev \
    libffi-dev \
    libyaml-dev \
    libpq-dev \
    libsqlite3-dev \
    libxml2-dev \
    lsb-release \
    binutils-multiarch \
    php \
    pkgconf \
    rsync \
    runit \
    shellcheck \
    vim \
    wget \
    curl \
    zip \
  && apt-get -qqy clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV MISE_DATA_DIR="/mise"
ENV MISE_CONFIG_DIR="/mise"
ENV MISE_CACHE_DIR="/mise/cache"
ENV MISE_INSTALL_PATH="/usr/local/bin/mise"
ENV PATH="/mise/shims:$PATH"

RUN curl https://mise.run | sh
RUN mise use -g ruby@3.4
RUN mise use -g go@latest
RUN mise use -g crystal@latest
RUN mise use -g python@3.10

# Import the CloudFoundry APT repo GPG key
RUN wget -q -O - https://raw.githubusercontent.com/cloudfoundry/bosh-apt-resources/master/public.key | apt-key add -
RUN echo "deb http://apt.ci.cloudfoundry.org stable main" | tee /etc/apt/sources.list.d/bosh-cloudfoundry.list
RUN apt-get -qqy update && apt-get -qqy install \
    bosh-cli \
    bosh-bootloader \
    cf-cli \
    credhub-cli \
    om-cli

# Create symlink for the cloudfoundry cli cf8 as cf
RUN ln -s /usr/bin/cf8 /usr/bin/cf

RUN curl -sSL https://get.docker.com/ | sh

RUN git config --global user.email "app-runtime-interfaces@cloudfoundry.org"
RUN git config --global user.name "app-runtime-interfaces@cloudfoundry.org"
RUN git config --global core.pager cat

# composer is a package manager for PHP apps
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/
RUN mv /usr/bin/composer.phar /usr/bin/composer

# NOTICE: this project is archived and not maintained since 2020
# Ensure Concourse Filter binary is present
RUN wget 'https://github.com/pivotal-cf-experimental/concourse-filter/releases/download/v0.1.2/concourse-filter' \
  && [ d0282138e9da80cc1e528dfaf1f95963908b9334ef1d27e461fc8cbbedc4c601 = $(shasum -a 256 concourse-filter | cut -d' ' -f1) ] \
  && mv concourse-filter /usr/local/bin \
  && chmod +x /usr/local/bin/concourse-filter

# Ensure that Concourse filtering is on for non-interactive shells
ENV BASH_ENV=/etc/profile.d/filter.sh

# AWS CLI
RUN pip install awscli

# install buildpacks-ci Gemfile
COPY Gemfile /tmp/Gemfile
COPY Gemfile.lock /tmp/Gemfile.lock
RUN /bin/bash -l -c "gem update --no-document \
  && gem install bundler \
  && cd /tmp && bundle install && bundle binstub bundler --force"

#install fly-cli
RUN curl "https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/api/v1/cli?arch=amd64&platform=linux" -sfL -o /usr/local/bin/fly \
  && chmod +x /usr/local/bin/fly

# NOTICE: the following release used is old and not maintained
# git-hooks and git-secrets
RUN curl -L https://github.com/git-hooks/git-hooks/releases/download/v1.1.4/git-hooks_linux_amd64.tar.gz -o githooks.tgz \
  && [ 3f21c856064f8f08f8c25494ac784882a2b8811eea3bfb721a6c595b55577c48 = $(shasum -a 256 githooks.tgz | cut -d' ' -f1) ] \
  && tar -zxf githooks.tgz --to-stdout > /usr/local/bin/git-hooks \
  && rm githooks.tgz \
  && chmod 755 /usr/local/bin/git-hooks

RUN git clone https://github.com/awslabs/git-secrets && cd git-secrets && make install

# Add git known host
RUN mkdir -p /root/.ssh/ && echo github.com,192.30.252.131 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ== > /root/.ssh/known_hosts

# Create testuser
RUN mkdir -p /home/testuser && \
  groupadd -r testuser -g 433 && \
  useradd -u 431 -r -g testuser -d /home/testuser -s /usr/sbin/nologin -c "Docker image test user" testuser
