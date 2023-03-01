FROM ubuntu:jammy

ENV LANG="C.UTF-8"
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qqy update \
  && apt-get -qqy install \
    curl \
    gnupg \
    apt-transport-https \
  && apt-get -qqy clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN apt-get -qqy update \
  && apt-get -qqy install \
    git \
    jq \
    gcc \
    php \
    ruby \
    make \
    shellcheck \
    vim \
    wget \
    zip \
  && apt-get -qqy clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV GEM_HOME $HOME/.gem
ENV GEM_PATH $HOME/.gem
ENV PATH /opt/rubies/latest/bin:$GEM_PATH/bin:$PATH

RUN curl -sSL https://get.docker.com/ | sh

# composer is a package manager for PHP apps
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/
RUN mv /usr/bin/composer.phar /usr/bin/composer

# download the bosh2 CLI
RUN curl -L https://github.com/cloudfoundry/bosh-cli/releases/download/v7.1.3/bosh-cli-7.1.3-linux-amd64 -o /usr/local/bin/bosh2 \
  && [ 901f5fedf406c063be521660ae5f7ccd34e034d3f734e0522138bc5bf71f4e80 = $(shasum -a 256 /usr/local/bin/bosh2 | cut -d' ' -f1) ] \
  && chmod +x /usr/local/bin/bosh2 \
  && ln -s /usr/local/bin/bosh2 /usr/local/bin/bosh

# # download bbl
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

Ensure Concourse Filter binary is present
RUN wget 'https://github.com/pivotal-cf-experimental/concourse-filter/releases/download/v0.1.2/concourse-filter' \
  && [ d0282138e9da80cc1e528dfaf1f95963908b9334ef1d27e461fc8cbbedc4c601 = $(shasum -a 256 concourse-filter | cut -d' ' -f1) ] \
  && mv concourse-filter /usr/local/bin \
  && chmod +x /usr/local/bin/concourse-filter

# when docker container starts, ensure login scripts run
COPY build/*.sh /etc/profile.d/

# Ensure that Concourse filtering is on for non-interactive shells
ENV BASH_ENV /etc/profile.d/filter.sh

RUN cd /usr/local \
  && curl -L https://dl.google.com/go/go1.19.3.linux-amd64.tar.gz -o go.tar.gz \
  && [ 74b9640724fd4e6bb0ed2a1bc44ae813a03f1e72a4c76253e2d5c015494430ba = $(shasum -a 256 go.tar.gz | cut -d' ' -f1) ] \
  && tar xf go.tar.gz \
  && rm go.tar.gz

ENV GOROOT=/usr/local/go
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# Create testuser
RUN mkdir -p /home/testuser && \
  groupadd -r testuser -g 433 && \
  useradd -u 431 -r -g testuser -d /home/testuser -s /usr/sbin/nologin -c "Docker image test user" testuser
