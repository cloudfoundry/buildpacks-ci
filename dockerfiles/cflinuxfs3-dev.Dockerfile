FROM cloudfoundry/cflinuxfs3

# Note: If this list starts to get long, we should consider using an external file to store the list of packages to remove.

RUN apt update && apt remove -y \
    libonig4 \
    libwebp6 \
    libruby2.5 \
    ruby \
    ruby2.5 \
    libldap2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
