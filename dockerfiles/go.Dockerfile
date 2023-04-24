FROM cfbuildpacks/feature-eng-ci:minimal

RUN \
  apt-get -qqy update \
  && apt-get -qqy install --fix-missing \
    runit \
  && apt-get -qqy clean

RUN mkdir -p /home/testuser \
  && groupadd -r testuser -g 433 \
  && useradd -u 431 -r -g testuser \
    -d /home/testuser \
    -s /usr/sbin/nologin \
    -c "Docker image test user" \
    testuser

ARG GO_VERSION=1.14
RUN curl "https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz" \
    --silent \
    --location \
    --output "/usr/local/go${GO_VERSION}.tar.gz" \
  && tar xzf "/usr/local/go${GO_VERSION}.tar.gz" -C /usr/local \
  && rm "/usr/local/go${GO_VERSION}.tar.gz"

ENV PATH="/usr/local/go/bin:${PATH}"
