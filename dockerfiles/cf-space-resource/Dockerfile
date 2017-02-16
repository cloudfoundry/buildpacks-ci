FROM cloudfoundry/cflinuxfs2

# download the CF-CLI
RUN curl --silent -L 'https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.24.0&source=github-rel' | tar xz -C /usr/bin && cf install-plugin Diego-Enabler -f -r CF-Community

# Copy in resources
ENV TMPDIR /tmp
RUN mkdir -p /opt/resource/
COPY check in out /opt/resource/

