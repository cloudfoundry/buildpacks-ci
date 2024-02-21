FROM ubuntu:bionic

ENV LANG="C.UTF-8"
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qqy update \
  && apt-get -qqy install \
    curl \
    gnupg \
    apt-transport-https \
  && apt-get -qqy clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -q https://dl.google.com/linux/linux_signing_key.pub | apt-key add -

COPY config/google-chrome-apt-key.pub /tmp/
RUN echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
  && apt-key add /tmp/google-chrome-apt-key.pub

RUN echo "deb http://packages.cloud.google.com/apt cloud-sdk-jessie main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
  && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

RUN curl -sL "https://keybase.io/crystal/pgp_keys.asc" | apt-key add - \
    && echo "deb https://dist.crystal-lang.org/apt crystal main" | tee /etc/apt/sources.list.d/crystal.list

RUN apt-get -qqy update \
  && apt-get -qqy install \
    aufs-tools \
    btrfs-progs \
    crystal \
    default-libmysqlclient-dev \
    expect \
    git \
    google-chrome-stable \
    google-cloud-sdk \
    iptables \
    jq \
    libgconf-2-4 \
    libpq-dev \
    libsqlite3-dev \
    libxml2-dev \
    lsb-release \
    multiarch-support \
    php7.0 \
    pkgconf \
    python-dev \
    python-pip \
    rsync \
    runit \
    shellcheck \
    vim \
    wget \
    zip \
  && apt-get -qqy clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN apt update \
    && apt install -y software-properties-common \
    &&  apt-add-repository -y ppa:brightbox/ruby-ng \
    &&  apt update \
    &&  apt install -y ruby2.7 ruby2.7-dev \
    &&  apt-get -qqy clean \
    &&  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV GEM_HOME $HOME/.gem
ENV GEM_PATH $HOME/.gem
ENV PATH /opt/rubies/latest/bin:$GEM_PATH/bin:$PATH

RUN curl -sSL https://get.docker.com/ | sh

RUN git config --global user.email "cf-buildpacks-eng@pivotal.io"
RUN git config --global user.name "CF Buildpacks Team CI Server"
RUN git config --global core.pager cat

# download om from pivotal-cf/om
RUN wget -O /usr/local/bin/om 'https://github.com/pivotal-cf/om/releases/download/7.8.2/om-linux-amd64-7.8.2' \
  && [ 68d2cbff67e699168ba16c84dc75e0ff40fcb6024f53f53579b7227b793df158 = $(shasum -a 256 /usr/local/bin/om | cut -d' ' -f1) ] \
  && chmod +x /usr/local/bin/om

# download and install chromedriver
RUN wget -O chromedriver.zip 'https://chromedriver.storage.googleapis.com/2.34/chromedriver_linux64.zip' \
  && [ e42a55f9e28c3b545ef7c7727a2b4218c37489b4282e88903e4470e92bc1d967 = $(shasum -a 256 chromedriver.zip | cut -d' ' -f1) ] \
  && unzip chromedriver.zip -d /usr/local/bin/ \
  && rm chromedriver.zip

# composer is a package manager for PHP apps
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/
RUN mv /usr/bin/composer.phar /usr/bin/composer

# download the bosh2 CLI
RUN curl -L https://github.com/cloudfoundry/bosh-cli/releases/download/v7.4.0/bosh-cli-7.4.0-linux-amd64 -o /usr/local/bin/bosh2 \
  && [ 98705c704beedb08621db48ab2f4cad42704b85aba36cc99f3a9dc2738ebc226 = $(shasum -a 256 /usr/local/bin/bosh2 | cut -d' ' -f1) ] \
  && chmod +x /usr/local/bin/bosh2 \
  && ln -s /usr/local/bin/bosh2 /usr/local/bin/bosh

# download bbl
RUN wget -O /usr/local/bin/bbl 'https://github.com/cloudfoundry/bosh-bootloader/releases/download/v8.4.111/bbl-v8.4.111_linux_x86-64' \
  && [ 5e8e87c2ae5562b9b592122661c0c4a1fe3066facdb9783a07229926845227bb = $(shasum -a 256 /usr/local/bin/bbl | cut -d' ' -f1) ] \
  && chmod +x /usr/local/bin/bbl

# download credhub cli
RUN curl -L https://github.com/cloudfoundry/credhub-cli/releases/download/2.9.10/credhub-linux-2.9.10.tgz -o credhub.tgz \
  && [ e1719d406f947f29b150b73db508c96afffb3b95f01f5031140c705b885b8a38 = $(shasum -a 256 credhub.tgz | cut -d' ' -f1) ] \
  && tar -zxf credhub.tgz --to-stdout > /usr/local/bin/credhub \
  && rm credhub.tgz \
  && chmod +x /usr/local/bin/credhub

# download CF cli
RUN curl -L "https://packages.cloudfoundry.org/stable?release=linux64-binary&source=github&version=v6" -o cf.tgz \
  && tar -zxf cf.tgz cf --to-stdout > /usr/local/bin/cf \
  && rm cf.tgz \
  && chmod +x /usr/local/bin/cf

# Ensure Concourse Filter binary is present
RUN wget 'https://github.com/pivotal-cf-experimental/concourse-filter/releases/download/v0.1.2/concourse-filter' \
  && [ d0282138e9da80cc1e528dfaf1f95963908b9334ef1d27e461fc8cbbedc4c601 = $(shasum -a 256 concourse-filter | cut -d' ' -f1) ] \
  && mv concourse-filter /usr/local/bin \
  && chmod +x /usr/local/bin/concourse-filter

# AWS CLI
RUN pip install awscli

# when docker container starts, ensure login scripts run
COPY build/*.sh /etc/profile.d/

# Ensure that Concourse filtering is on for non-interactive shells
ENV BASH_ENV /etc/profile.d/filter.sh

# install buildpacks-ci Gemfile
COPY Gemfile /tmp/Gemfile
COPY Gemfile.lock /tmp/Gemfile.lock
RUN /bin/bash -l -c "gem update --system 3.4.22 --no-document \
  && gem install bundler -v 2.4.22 \
  && cd /tmp && bundle install && bundle binstub bundler --force"

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

RUN export GO_VERSION=$(wget -qO- https://golang.org/dl/\?mode\=json | jq -r '.[0].version' | sed 's/go//') && \
    wget -q https://golang.org/dl/go$GO_VERSION.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz

ENV GOROOT=/usr/local/go
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# Add git known host
RUN mkdir -p /root/.ssh/ && echo github.com,192.30.252.131 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ== > /root/.ssh/known_hosts

# Create testuser
RUN mkdir -p /home/testuser && \
  groupadd -r testuser -g 433 && \
  useradd -u 431 -r -g testuser -d /home/testuser -s /usr/sbin/nologin -c "Docker image test user" testuser
