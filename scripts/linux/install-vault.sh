#!/bin/bash

# Install Vault CLI  (https://www.vaultproject.io/downloads.html)
VAULT_VERSION="1.1.2"

curl -O https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip vault_${VAULT_VERSION}_linux_amd64.zip
sudo mv vault /usr/local/bin/
vault -autocomplete-install
complete -C /usr/local/bin/vault vault
vault --version

vault -autocomplete-install
complete -C /usr/local/bin/vault vault
