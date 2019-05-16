#!/bin/bash
BASEDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )")
source "${BASEDIR}/scripts/functions.sh"

# ------------------------------------------------------------------------------
# Cluster Initializaton (Helm/Tiller)
# ------------------------------------------------------------------------------

# Install the Service Accounts and RBAC for Helm/Tiller.
# Follow up by initializing Helm/Tiller on the cluster.
echo "Setting up resources and initializing Helm/Tiller..."
kubectl -n kube-system create serviceaccount tiller > /dev/null 2>&1
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller > /dev/null 2>&1
helm init --service-account tiller && helm repo update > /dev/null 2>&1

if [[ $? -ne 0 ]]; then
  echo -e "\033[31mThere was a problem intializing Tiller.\033[39m"
  exit 1
fi

kubectl rollout status deployment/tiller-deploy  -n kube-system -w > /dev/null 2>&1 & \
spinner "Awaiting Helm/Tiller availability"

echo -e "\033[32mHelm/Tiller is ready.\033[39m"
