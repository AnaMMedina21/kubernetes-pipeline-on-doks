#!/bin/bash

# ------------------------------------------------------------------------------
# External DNS Setup
# ------------------------------------------------------------------------------
NAME="External DNS controller"

# ExternalDNS synchronizes exposed Kubernetes Services and Ingresses with DNS providers.
echo "Installing $NAME..."
echo -e "\033[31mThis controller will by automatically configures DNS records in DNS server based on service amd ingress annotations..\033[39m"

API_TOKEN=$(doctl auth init | awk -F"[][]" '{print $2}')
NAMESPACE=default

helm upgrade \
  --install external-dns \
  --namespace $NAMESPACE \
  --set digitalocean.apiToken=$API_TOKEN \
  --set provider=digitalocean \
  --set rbac.create=true \
  stable/external-dns > /dev/null 2>&1

if [[ $? -eq 0 ]]; then
  echo -e "\033[32m$NAME has been installed successfully!\033[39m"
else
  echo -e "\033[31mThere was a problem installing the $NAME.\033[39m"
  exit 1
fi

# Wait for the External DNS controller to come online before continuing.
echo "Please wait while the $NAME comes online..."
until [[ $(kubectl get pods -n $NAMESPACE -l "app=external-dns,release=external-dns" 2> /dev/null | grep external-dns | awk -F " " '{print $2}' | awk -F "/" '{print $1}') -ge "1" ]]; do
  echo -n "."
  sleep 1
done
echo

echo -e "\033[32m$NAME is now available.\033[39m"
echo