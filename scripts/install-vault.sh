#!/bin/bash

BASEDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )")
source "${BASEDIR}/scripts/functions.sh"

# -----------------------------------------------------------------------------
# Install Vault
# -----------------------------------------------------------------------------

NAMESPACE=vault

echo "HashiCorp Vault will now be installed onto the cluster."

# Per instructions here: https://operatorhub.io/operator/vaultoperator.v0.4.10
kubectl create namespace $NAMESPACE
# kubectl create -f https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/olm.yaml
# kubectl create -f https://operatorhub.io/install/vaultoperator.yaml

# Per article: https://github.com/kubevault/docs/blob/master/docs/setup/README.md
helm repo add appscode https://charts.appscode.com/stable/
helm repo update
helm install appscode/vault-operator --wait --name vault-operator --version 0.2.0 --namespace $NAMESPACE
kubectl get crd -l app=vault

# TODO: An alternative for setting up Vault operator iwth a Helm chart, but more complicated
# Install Vault (Latest version tag here: https://hub.docker.com/r/banzaicloud/vault-operator)
# IMAGE_TAG=0.4.16
# helm repo add banzaicloud-stable http://kubernetes-charts.banzaicloud.com/branch/master
# helm install banzaicloud-stable/vault-operator \
#              --wait \
#              --namespace=$NAMESPACE \
#              --name vault-operator \
#              --set image.tag=$IMAGE_TAG \
#              --set etcd-operator.enabled=true \
#              --set=etcd-operator.etcdOperator.commandArgs.cluster-wide=true
# kubectl apply -n $NAMESPACE -f https://raw.githubusercontent.com/banzaicloud/bank-vaults/master/operator/deploy/cr-etcd-ha.yaml

export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
export VAULT_TOKEN=$(kubectl get secrets vault-unseal-keys -o jsonpath={.data.vault-root} | base64 -d)

# Install Vault CLI  (https://www.vaultproject.io/downloads.html)
"${BASEDIR}"/$MACHINE/install-vault.sh
vault --version

echo -e "\033[32mVault is ready.\033[39m"
echo -e "\033[33mTo access Vault, you must run the following command in a terminal window:\033[39m"
echo "kubectl port-forward -n $NAMESPACE service/vault 8200:8200"

ACCESS_TOKEN=$(kubectl -n $NAMESPACE describe secret $(kubectl -n $NAMESPACE get secret | grep admin-user | awk '{print $1}') | grep 'token:' | awk -F " " '{print $2}')

echo "The Vault access token is: $VAULT_TOKEN"
