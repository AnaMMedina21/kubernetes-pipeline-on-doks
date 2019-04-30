#!/bin/bash

# ------------------------------------------------------------------------------
# Dependency Check
# ------------------------------------------------------------------------------

echo "Checking dependencies..."

# Install Homebrew.
if [ -z $(command -v brew) ]; then
  echo -e "\033[31mHomebrew was not found.\033[39m"
  echo "Installing Homebrew, please wait..."

  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

  # Double check that Homebrew was installed.
  # If it was not installed properly, we do not want to continue the script.
  if [ -z $(command -v brew) ]; then
    echo -e "\033[31mThere was an error installing Homebrew." \
            "Homebrew is required to install the remaining dependencies.\033[39m"
    exit 1
  fi
else
  echo "Homebrew is already installed."
fi

# Install Kubectl.
if [ -z $(command -v kubectl) ]; then
  echo -e "\033[31mKubectl was not found.\033[39m"
  echo "Installing Kubectl, please wait..."

  brew install kubernetes-cli

  # Double check that Kubectl was installed.
  if [ -z $(command -v kubectl) ]; thenco
    echo -e "\033[31mThere was an error installing Kubectl. Kubectl is" \
            "required to connect to the Kubernetes cluster.\033[39m"
    exit 1
  fi
else
  echo -e "Kubectl is already installed."
fi

# Install Helm.
if [ -z $(command -v helm) ]; then
  echo -e "\033[31mHelm was not found.\033[39m"
  echo -e "Installing Helm, please wait..."

  brew install kubernetes-helm

  # Double check that Helm was installed.
  if [ -z $(command -v helm) ]; then
    echo -e "\033[31mThere was an error installing Helm. Helm is required to" \
            "install software to the Kubernetes cluster.\033[39m"
    exit 1
  fi
else
  echo -e "Helm is already installed."
fi

# Install Doctl.
if [ -z $(command -v doctl) ]; then
  echo -e "\033[31mDoctl was not found.\033[39m"
  echo -e "Installing Doctl, please wait..."

  brew install doctl

  # Double check that Doctl was installed.
  if [ -z $(command -v doctl) ]; then
    echo -e "\033[31mThere was an error installing Doctl." \
            "Doctl is required to interact with DigitalOcean.\033[39m"
    exit 1
  fi
else
  echo -e "Doctl is already installed."
fi
