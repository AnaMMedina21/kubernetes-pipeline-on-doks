#!/bin/bash

BASEDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )")
source "${BASEDIR}/scripts/functions.sh"

# ------------------------------------------------------------------------------
# Create Cluster
# ------------------------------------------------------------------------------
# In order to create a cluster we need the following:
# Cluster Name, Region, Version, Node Size, Node Count
# ------------------------------------------------------------------------------

# Cluster Name
# TODO: Add validation to this. No empty values, double check if spaces are allowed.
echo -e "\033[33mWhat would you like to name this cluster?\033[39m"
read -p "Cluster name: " CLUSTER_NAME
echo

echo "Fetching Kubernetes information, please wait..."
echo

REGIONS=($(doctl k8s options regions -o text | awk '{if(NR>1)print $1}'))
VERSIONS=($(doctl k8s options versions -o text | awk '{if(NR>1)print $1}'))
NODE_SIZES=($(doctl k8s options sizes -o text | awk '{if(NR>1)print $1}'))

# Cluster Region
echo -e "\033[33mSelect the region where Kubernetes will be running?\033[39m"
select_option "${REGIONS[@]}"
choice=$?
CLUSTER_REGION="${REGIONS[$choice]}"

# Kubernetes Version
echo -e "\033[33mWhich version of Kubernetes should be applied?\033[39m"
select_option "${VERSIONS[@]}"
choice=$?
CLUSTER_VERSION="${VERSIONS[$choice]}"

# Node Size
echo -e "\033[33mSelect the desired size for all nodes in this cluster.\033[39m"
select_option "${NODE_SIZES[@]}"
choice=$?
NODE_SIZE="${NODE_SIZES[$choice]}"

# Node Count
echo -e "\033[33mHow many worker nodes to allocate for this Kubernetes cluster?\033[39m"

while true; do
  read -p "Desired node count [3]: " NODE_COUNT
  # Make sure that the entry is a number that is between 1-10.
  if [[ $NODE_COUNT -gt 0 && $NODE_COUNT -lt 11 ]]; then
    break
  else
    echo -e "\033[31mError: Given value is not a valid entry. The count must be from 1 to 10. Please try again.\033[39m"
  fi
done
echo

# Cluster Creation
echo -e "A Kubernetes cluster with the following configuration will be created.\033[39m"
echo "Name: $CLUSTER_NAME"
echo "Region: $CLUSTER_REGION"
echo "Version: $CLUSTER_VERSION"
echo "Node Size: $NODE_SIZE"
echo "Node Count: $NODE_COUNT"
echo

echo "Creating a new Kubernetes cluster, please wait a few minutes..."
doctl kubernetes cluster create "${CLUSTER_NAME}" \
  --region "${CLUSTER_REGION}" \
  --version "${CLUSTER_VERSION}" \
  --size "${NODE_SIZE}" \
  --count "${NODE_COUNT}"

if [[ $? -eq 0 ]]; then
  echo -e "\033[32mThe Kubernetes cluster has been created.\033[39m"
else
  echo -e "\033[31mThere was a problem creating the Kubernetes cluster.\033[39m"
  exit 1
fi

# Set the proper context for the cluster.
CLUSTER_CONTEXT="do-${CLUSTER_REGION}-${CLUSTER_NAME}"
kubectl config use-context "${CLUSTER_CONTEXT}" > /dev/null

if [[ $? -eq 0 ]]; then
  echo -e "\033[32mKubectl has been configured to use $CLUSTER_CONTEXT as the default context.\033[39m"
else
  echo -e "\033[31mThere was a problem setting the default context for kubectl.\033[39m"
  exit 1
fi

kubectl rollout status deployment/coredns -n kube-system > /dev/null & spinner "Waiting for the cluster to be available"

echo -e "\033[32mKubernetes is ready.\033[39m"
