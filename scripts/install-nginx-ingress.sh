#!/bin/bash
BASEDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )")
source "${BASEDIR}/scripts/functions.sh"

# ------------------------------------------------------------------------------
# Nginx Ingress Setup
# ------------------------------------------------------------------------------

# This will also set up a load balancer on the DigitalOcean account.
echo -e "\033[31mThe Nginx chart will by association create a Load Balancer on the" \
        "associated DigitalOcean account.\033[39m"
helm upgrade --install nginx-ingress --wait --namespace nginx-ingress stable/nginx-ingress > /dev/null 2>&1 \
& spinner "Installing Nginx Ingress. This will take 2-3 minutes."

if [[ $? -ne 0 ]]; then
  echo -e "\033[31mThere was a problem installing the Nginx Ingress.\033[39m"
  exit 1
fi

echo -e "\033[32mNginx Ingress is ready.\033[39m"
