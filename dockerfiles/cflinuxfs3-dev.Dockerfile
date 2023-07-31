FROM cloudfoundry/cflinuxfs3

RUN apt update

# Remove ESM packages required for dependenciees

## PHP
RUN apt remove libonig4 -y
