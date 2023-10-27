FROM cloudfoundry/cflinuxfs3

# Note: If this list starts to get long, we should consider using an external file to store the list of packages to remove.

# Remove packages that are installed with an ESM version that is not compatible with some compilation processes for dependencies.
RUN apt update && apt remove -y \
    libonig4 \
    libwebp6 \
    libsnmp-dev
