FROM cloudfoundry/cflinuxfs2

# download the CF-CLI
RUN curl --silent -L 'https://cli.run.pivotal.io/stable?release=linux64-binary' | tar xz -C /usr/bin

# Copy in resources
ENV TMPDIR /tmp
RUN mkdir -p /opt/resource/
COPY check in out /opt/resource/

