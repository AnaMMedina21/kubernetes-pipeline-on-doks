#!/bin/bash

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
source "${BASEDIR}/scripts/functions.sh"

# ------------------------------------------------------------------------------
# Dependency Check
# ------------------------------------------------------------------------------

echo "Checking dependencies..."

# Install native package manager.
"${BASEDIR}"/$MACHINE/install-package-manager.sh

# Install Kubectl CLI tool.
if [ -z $(command -v kubectl) ]; then
  echo -e "\033[31mKubectl was not found.\033[39m"
  echo "Installing Kubectl, please wait..."

  "${BASEDIR}"/$MACHINE/kubectl-install.sh

  # Double check that Kubectl was installed.
  if [ -z $(command -v kubectl) ]; then
    echo -e "\033[31mThere was an error installing Kubectl. Kubectl is" \
            "required to connect to the Kubernetes cluster.\033[39m"
    exit 1
  else
    echo "kubectl installed."
    kubectl version
  fi
else
  echo -e "Kubectl is already installed."
fi

# Install Helm CLI tool.
if [ -z $(command -v helm) ]; then
  echo -e "\033[31mHelm was not found.\033[39m"
  echo -e "Installing Helm, please wait..."

  "${BASEDIR}"/$MACHINE/helm-install.sh

  # Double check that Helm was installed.
  if [ -z $(command -v helm) ]; then
    echo -e "\033[31mThere was an error installing Helm. Helm is required to" \
            "install software to the Kubernetes cluster.\033[39m"
    exit 1
  else
    echo "helm installed."
    helm version
  fi
else
  echo -e "Helm is already installed."
fi

# Install Doctl CLI.
if [ -z $(command -v doctl) ]; then
  echo -e "\033[31mDoctl was not found.\033[39m"
  echo -e "Installing Doctl, please wait..."

  "${BASEDIR}"/$MACHINE/doctl-install.sh

  # Double check that Doctl was installed.
  if [ -z $(command -v doctl) ]; then
    echo -e "\033[31mThere was an error installing Doctl." \
            "Doctl is required to interact with DigitalOcean.\033[39m"
    exit 1
  else
    echo "doctl installed."
    helm version
  fi
else
  echo -e "Doctl is already installed."
fi

# Install Halyard (hal) CLI tool.
if [ -z $(command -v hal) ]; then
  echo -e "\033[31mHalyard (hal) was not found.\033[39m"
  echo -e "Installing Halyard (hal), please wait..."

  "${BASEDIR}"/$MACHINE/install-halyard.sh

  # Double check that Halyard was installed.
  if [ -z $(command -v hal) ]; then
    echo -e "\033[31mThere was an error installing Halyard." \
            "Halyard is required to interact with Spinnaker on DigitalOcean.\033[39m"
    exit 1
  else
    echo "Halyard (hal) installed."
    helm version
  fi
else
  echo -e "Halyard (hal) is already installed."
fi

# ------------------------------------------------------------------------------
# Dependency Check: Generic
# ------------------------------------------------------------------------------

if [[ -z $(doctl auth init 2>/dev/null | grep "Validating token... OK") ]]; then
  echo -e "\033[31mAn access token for doctl was not found.\033[39m"
  echo "In order to interact with DigitalOcean, doctl must authenticate using an access token."
  echo "This token can be created via the Applicatons & API section of the DigitalOcean Control Panel."
  echo "https://cloud.digitalocean.com/account/api/tokens"
  echo "When created, ensure this token has both read and write access."
  echo

  while true; do
    echo -e "\033[33mPlease provide your DigitalOcean API Token\033[39m: "
    read DO_TOKEN

    doctl auth init -t "${DO_TOKEN}" > /dev/null 2>&1

    if [[ $? -eq 0 ]]; then
      echo "\033[32mTDoctl can now communicate with DigitalOcean with the valid token.\033[39m"
      break
    else
      echo -e "\033[31mThere was an error authenticating with DigitalOcean. Please try again.\033[39m"
    fi
  done
fi
echo

