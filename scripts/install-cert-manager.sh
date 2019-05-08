#!/bin/bash

BASEDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )")
source "${BASEDIR}/scripts/functions.sh"

echo "Adding prerequisites for Cert Manager, according to readme in stable/cert-manager..."
kubectl apply \
    -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml

kubectl label namespace kube-system certmanager.k8s.io/disable-validation="true"
echo

# -----------------------------------------------------------------------------
# Install Cert Manager
# -----------------------------------------------------------------------------

echo "Installing Cert Manager. This will take 1-2 minutes."
helm upgrade --install cert-manager --namespace kube-system stable/cert-manager > /dev/null 2>&1

if [[ $? -eq 0 ]]; then
  echo -e "\033[32mCert Manager has been installed.\033[39m"
else
  echo -e "\033[31mThere was a problem installing Cert Manager.\033[39m"
  exit 1
fi

# Wait for the Certificate Manager to come online before trying to create any Cluster Issuers.
echo "Please wait while the Cert Manager Deployment is complete..."
kubectl rollout status deployment/cert-manager -n kube-system --watch
echo

echo -e "\033[32mCert Manager is ready.\033[39m"
echo

# Email for Let's Encrypt certificates
echo -en "\033[33mLet's Encrypt uses an email to contact you about expiring certificates, and issues related to your account. Please enter your email address used for ACME registration\033[39m: " | fold -s
read EMAIL
echo

sed -E 's/\[EMAIL\]/'"$EMAIL"'/' \
  "${BASEDIR}"/templates/cluster-issuers.yaml > "${BASEDIR}"/files/cluster-issuers.yaml

echo "Configuring default Cluster Issuers for staging and production..."
kubectl apply -f "${BASEDIR}"/files/cluster-issuers.yaml > /dev/null 2>&1

if [[ $? -ne 0 ]]; then
  echo -e "\033[31mThere was a problem configuring the Cluster Issuers.\033[39m"
  exit 1
fi

echo -e "\033[32mCluster Issuers have been configured.\033[39m"
