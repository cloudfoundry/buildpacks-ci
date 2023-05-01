FROM ubuntu:bionic

ENV LANG="C.UTF-8"
ENV DEBIAN_FRONTEND noninteractive

ARG GO_VERSION=1.19.3
ARG GO_SHA256=74b9640724fd4e6bb0ed2a1bc44ae813a03f1e72a4c76253e2d5c015494430ba
ARG BOSH_VERSION=7.1.3
ARG BBL_VERSION=8.4.111
ARG CREDHUB_VERSION=2.9.10
ARG OM_VERSION=7.1.1
ARG PACK_VERSION=0.24.0

RUN apt-get -qqy update \
  && apt-get -qqy install \
    build-essential \
    curl

RUN curl -sL "https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key" | apt-key add - \
  && echo "deb https://packages.cloudfoundry.org/debian stable main" | tee /etc/apt/sources.list.d/cloudfoundry-cli.list

RUN apt-get -qqy update \
  && apt-get -qqy install \
    cf8-cli \
    git \
    jq \
    unzip \
    vim \
    zip

RUN git config --global user.email "buildpacks-releng@pivotal.io"
RUN git config --global user.name "Buildpacks Releng CI"

RUN curl -sL https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz -o /tmp/go.tar.gz \
  && [ ${GO_SHA256} = $(shasum -a 256 /tmp/go.tar.gz | cut -d' ' -f1) ] \
  && tar -C /usr/local -xf /tmp/go.tar.gz \
  && rm /tmp/go.tar.gz

ENV GOROOT=/usr/local/go
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:$GOROOT/bin:$PATH

RUN curl -sL -o /usr/local/bin/yj https://github.com/sclevine/yj/releases/latest/download/yj-linux-amd64 \
  && chmod +x /usr/local/bin/yj

RUN curl -sL -o /usr/local/bin/fly "https://buildpacks.ci.cf-app.com/api/v1/cli?arch=amd64&platform=linux" \
  && chmod +x /usr/local/bin/fly

RUN curl -sL -o /usr/local/bin/bosh https://github.com/cloudfoundry/bosh-cli/releases/download/v${BOSH_VERSION}/bosh-cli-${BOSH_VERSION}-linux-amd64 \
  && chmod +x /usr/local/bin/bosh

RUN curl -sL -o /usr/local/bin/bbl https://github.com/cloudfoundry/bosh-bootloader/releases/download/v${BBL_VERSION}/bbl-v${BBL_VERSION}_linux_x86-64 \
  && chmod +x /usr/local/bin/bbl

RUN curl -sL https://github.com/cloudfoundry-incubator/credhub-cli/releases/download/${CREDHUB_VERSION}/credhub-linux-${CREDHUB_VERSION}.tgz \
  | tar -C /usr/local/bin -xz

RUN curl -sL -o /usr/local/bin/om https://github.com/pivotal-cf/om/releases/download/${OM_VERSION}/om-linux-${OM_VERSION} \
  && chmod +x /usr/local/bin/om

RUN curl -sL https://github.com/buildpacks/pack/releases/download/v${PACK_VERSION}/pack-v${PACK_VERSION}-linux.tgz \
  | tar -C /usr/local/bin -xz

RUN curl -sSL https://get.docker.com/ | sh

RUN curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip \
  && unzip -d /tmp /tmp/awscliv2.zip \
  && /tmp/aws/install \
  && rm -rf /tmp/aws /tmp/awscliv2.zip

# Create testuser
RUN mkdir -p /home/testuser && \
  groupadd -r testuser -g 433 && \
  useradd -u 431 -r -g testuser -d /home/testuser -s /usr/sbin/nologin -c "Docker image test user" testuser

RUN apt-get -qqy clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
