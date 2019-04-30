#!/bin/bash
set -e

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
source "${BASEDIR}/scripts/functions.sh"

# ------------------------------------------------------------------------------
# Introduction
# ------------------------------------------------------------------------------

echo "Started install $(date)"

echo -e "This script will eases the process of setting up a" \
        "Kubernetes cluster, for CI/CD purposes, from scratch on" \
        "DigitalOcean. It first checks for any necessary" \
        "dependencies and installs them if necessary. After" \
        "this you will be guided through each step of the process," \
        "being prompted for the necessary information needed for configuration." | fold -s
echo    
echo -e "Let’s start by checking those dependencies, here's what we're looking for:" \
        "Kubectl, Helm, and Doctl." | fold -s
echo

read -p $'\033[33mPress enter to continue...\033[39m'
echo


# ------------------------------------------------------------------------------
# Check Dependencies: Brew, Kubectl, Helm, Doctl.
# ------------------------------------------------------------------------------
if [ $machine == "Mac" ]; then
  "${BASEDIR}"/scripts/dependency-check-mac.sh
elif [ $machine == "Linux" ]; then
  "${BASEDIR}"/scripts/dependency-check-linux.sh
fi

"${BASEDIR}"/scripts/dependency-check-generic.sh


# ------------------------------------------------------------------------------
# Create Cluster
# ------------------------------------------------------------------------------

if ask "Create a new Kubernetes cluster?"; then
  echo
  "${BASEDIR}"/scripts/create-cluster.sh
else # Copy Config
  echo
  if ask "Apply the existing Kubernetes config to kubectl context?" Y; then
    echo
    "${BASEDIR}"/scripts/copy-config.sh
  fi
  echo
fi
echo


# ------------------------------------------------------------------------------
# Cluster Initializaton (Helm/Tiller)
# ------------------------------------------------------------------------------

if ask "Initialize Helm/Tiller?" Y; then
  echo
  "${BASEDIR}"/scripts/install-helm-tiller.sh
else
  echo
fi
echo

# ------------------------------------------------------------------------------
# Dashboard Setup
# ------------------------------------------------------------------------------

if ask "Install Kubernetes Dashboard?" Y; then
  echo
  "${BASEDIR}"/scripts/install-dashboard.sh
else
  echo
fi
echo

# ------------------------------------------------------------------------------
# Nginx Ingress Setup
# ------------------------------------------------------------------------------

if ask "Install the Nginx Ingress?" Y; then
  echo
  "${BASEDIR}"/scripts/install-nginx-ingress.sh
else
  echo
fi
echo


# ------------------------------------------------------------------------------
# Create DNS A Record for Ingress Setup
# ------------------------------------------------------------------------------
if ask "Create a DNS A record for the cluster ingress?" Y ;then
  echo
  "${BASEDIR}"/scripts/create-dns.sh
else
  echo
fi
echo


# ------------------------------------------------------------------------------
# Certificate Manager Setup
# ------------------------------------------------------------------------------

if ask "Install Cert Manager?" Y; then
  echo
  "${BASEDIR}"/scripts/install-cert-manager.sh
else
  echo
fi
echo


# ------------------------------------------------------------------------------
# Jenkins Setup
# ------------------------------------------------------------------------------

if ask "Install and configure Jenkins?" Y; then
  echo
  "${BASEDIR}"/scripts/install-jenkins.sh
else
  echo
fi
echo


# ------------------------------------------------------------------------------
# Harbor Setup
# ------------------------------------------------------------------------------

if ask "Install and configure Harbor?" Y; then
  echo
  "${BASEDIR}"/scripts/install-harbor.sh
else
  echo
fi
echo

echo "Kubernetes cluster install and provisioning complete $(date)"
