#!/bin/bash
set -e

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
source "${BASEDIR}/scripts/functions.sh"

# ------------------------------------------------------------------------------
# Introduction
# ------------------------------------------------------------------------------
echo
echo -e "This script will eases the process of setting up a" \
        "Kubernetes cluster, for CI/CD purposes, from scratch on" \
        "DigitalOcean. It first checks for any necessary" \
        "dependencies and installs them if necessary. After" \
        "this you will be guided through each step of the process," \
        "being prompted for the necessary information needed for configuration." | fold -s
echo    

read -p $'\033[33mPress enter to continue...\033[39m'
echo "Install started $(date)"
echo

# ------------------------------------------------------------------------------
# Check Dependencies: Brew, Kubectl, Helm, Doctl.
# ------------------------------------------------------------------------------
if ask "Locally, you will need some common tools as prerequisites.\nInstall these local CLI tools: Kubectl, Helm, Doctl, and Halyard (hal)?" Y; then
  echo
  "${BASEDIR}"/scripts/dependency-check.sh
else
  echo
fi
echo


# ------------------------------------------------------------------------------
# Create Cluster
# ------------------------------------------------------------------------------
if ask "A Kubernetes cluster on DigitalOcean (DOKS) is needed.\nCreate a new Kubernetes cluster?"; then
  echo
  "${BASEDIR}"/scripts/create-cluster.sh
else # Copy Config
  echo
  if ask "Apply the existing Kubernetes config to kubectl context?" Y; then
    echo
    "${BASEDIR}"/scripts/copy-config.sh
  fi
fi
echo


# ------------------------------------------------------------------------------
# Cluster Initializaton (Helm/Tiller)
# ------------------------------------------------------------------------------
if ask "Helm is a package manager for Kubernetes.\nInstall Helm and initialize its Tiller component?" Y; then
  echo
  "${BASEDIR}"/scripts/install-helm-tiller.sh
fi
echo

# ------------------------------------------------------------------------------
# Dashboard Setup
# ------------------------------------------------------------------------------
if ask "Kubernetes has a generic dashboard for administration.\nInstall the Kubernetes Dashboard?" Y; then
  echo
  "${BASEDIR}"/scripts/install-dashboard.sh
fi
echo

# ------------------------------------------------------------------------------
# Nginx Ingress Setup
# ------------------------------------------------------------------------------
if ask "Inbound cluster traffic is routed through a Kubernetes Ingress.\nInstall the Nginx Ingress controller?" Y; then
  echo
  "${BASEDIR}"/scripts/install-nginx-ingress.sh
fi
echo


# ------------------------------------------------------------------------------
# Create DNS A Record for Ingress Setup
# ------------------------------------------------------------------------------
if ask "Traffic routed from a DNS needs to be fed to a load balancer via an A record.\nCreate a DNS A record for the cluster's Ingress?" Y ;then
  echo
  "${BASEDIR}"/scripts/create-dns.sh
fi
echo


# ------------------------------------------------------------------------------
# Certificate Manager Setup
# ------------------------------------------------------------------------------
if ask "Inbound traffic must be https with TLS certificates.\nInstall a certificate manager (cert-manager)?" Y; then
  echo
  "${BASEDIR}"/scripts/install-cert-manager.sh
fi
echo


# ------------------------------------------------------------------------------
# Harbor Setup
# ------------------------------------------------------------------------------
if ask "Harbor is a registry tool for holding artifacts such as containers and Helm charts.\nInstall and configure Harbor?" Y; then
  echo
  "${BASEDIR}"/scripts/install-harbor.sh
fi
echo

echo "Your Kubernetes cluster install and provisioning is complete. $(date)"


# ------------------------------------------------------------------------------
# Jenkins Setup
# ------------------------------------------------------------------------------
if ask "Jenkins is a continuous integration (CI) tool.\nInstall and configure Jenkins?" Y; then
  echo
  "${BASEDIR}"/scripts/install-jenkins.sh
fi
echo

# ------------------------------------------------------------------------------
# Spinnaker Setup
# ------------------------------------------------------------------------------
if ask "Spinnaker is a continuous deliver pipeline tool for distributing your applications to cluster.\nInstall and configure Spinnaker?" Y; then
  echo
  "${BASEDIR}"/scripts/install-spinnaker.sh
fi
echo

# ------------------------------------------------------------------------------
# La fin
# ------------------------------------------------------------------------------
echo "Your Kubernetes cluster provisioning is complete. $(date)"
