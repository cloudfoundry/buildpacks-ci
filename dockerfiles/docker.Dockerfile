FROM cfbuildpacks/feature-eng-ci:minimal

RUN apt-get -qqy update \
  && apt-get -qqy install \
    apt-transport-https \
    ca-certificates \
    gnupg-agent \
    software-properties-common \
  && apt-get -qqy clean \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
  && add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  && apt-get -qqy install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    iproute2 \
  && apt-get -qqy clean
