#!/bin/bash

# ------------------------------------------------------------------------------
# Dependency Check
# ------------------------------------------------------------------------------

echo "Checking dependencies..."

# Install Kubectl.
# echo todo, as a work around have tool preinstalled

# curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
# chmod +x ./kubectl
# sudo mv ./kubectl /usr/local/bin/kubectl

# Install Helm.
# 

echo todo, as a work around have tool preinstalled

# Install Doctl.
# echo todo, as a work around have tool preinstalled
if [ $(doctl version | head -1 | wc -l) -ne 1  ]; then
  echo -e "\033[31mDoctl was not found.\033[39m"
  echo -e "Installing Doctl, please wait..."
  
  VER='1.16.0'
  
  curl -sL "https://github.com/digitalocean/doctl/releases/download/v$VER/doctl-$VER-linux-amd64.tar.gz" | tar -xzv
  sudo mv ~/doctl /usr/local/bin

  # Double check that Doctl was installed.
  if [ -z $(doctl version) ]; then
    echo -e "\033[31mThere was an error installing Doctl." \
            "Doctl is required to interact with DigitalOcean.\033[39m"
    exit 1
  fi
else
  echo -e "Doctl is already installed."
fi
