#!/bin/bash

BASEDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )")
source "${BASEDIR}/scripts/functions.sh"

# -----------------------------------------------------------------------------
# Install Kubernetes Dashboard
# -----------------------------------------------------------------------------

echo "Kubernetes Dashboard will now be installed onto the cluster."

# Access token
echo "Setting up an access token..."
cp "${BASEDIR}"/templates/dashboard-auth.yaml "${BASEDIR}"/files/dashboard-auth.yaml > /dev/null 2>&1
kubectl apply -f "${BASEDIR}"/files/dashboard-auth.yaml > /dev/null 2>&1
ACCESS_TOKEN=$(kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}') | grep 'token:' | awk -F " " '{print $2}')

if [[ $? -eq 0 ]]; then
  echo -e "\033[32mAccess token created.\033[39m"
else
  echo -e "\033[31mThere was a problem creating the dashboard access token.\033[39m"
fi

# Install Dashboard
cp "${BASEDIR}"/templates/dashboard-values.yaml "${BASEDIR}"/files/dashboard-values.yaml > /dev/null 2>&1
helm upgrade --install --wait kubernetes-dashboard --namespace kube-system stable/kubernetes-dashboard --values "${BASEDIR}"/files/dashboard-values.yaml > /dev/null 2>&1 & \
spinner "Installing dashboard onto Kubernetes cluster"

echo -e "\033[32mKubernetes Dashboard is ready.\033[39m"
echo -e "\033[33mTo access the dashboard, you must run the following command in a terminal window:\033[39m"
echo "kubectl proxy&"
echo -e "\033[33mOnce the proxy has been opened, the dashboard may be accessed via\033[39m:"
echo "http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy/"
echo -e "\033[33mThe following access token can be used to log in to the dashboard\033[39m:"
echo "${ACCESS_TOKEN}"
