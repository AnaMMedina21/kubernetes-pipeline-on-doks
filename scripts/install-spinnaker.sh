#!/bin/bash

BASEDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )")
source "${BASEDIR}/scripts/functions.sh"
NOTES="${BASEDIR}/files/install-notes.md"

# -----------------------------------------------------------------------------
# Install Spinnaker
# -----------------------------------------------------------------------------
# When installing Spinnaker....
# -----------------------------------------------------------------------------

echo "Spinnaker will now be installed onto the Kubernetes cluster."
echo

# Prerequisites: K8s cluster ready with Kubctl, DoCtl and Hal already installed
#
# These steps are based on the instructions here:
# https://www.digitalocean.com/community/tutorials/how-to-set-up-a-cd-pipeline-with-spinnaker-on-digitalocean-kubernetes
# https://medium.com/parkbee-tech/spinnaker-installation-on-kubernetes-using-new-halyard-based-helm-chart-d0cc7f0b8fd0

# Tell Spinnaker where it should deploy to
# hal config provider kubernetes enable

# Create a Kubernetes namepsace for Spinnaker
kubectl create ns spinnaker

# Install Spinnaker
cp "${BASEDIR}"/templates/spinnaker-values.yaml "${BASEDIR}"/files/spinnaker-values.yaml > /dev/null 2>&1
helm upgrade \
spinnaker \
stable/spinnaker \
--install \
--namespace spinnaker \
--timeout 1200 \
--values /files/spinnaker-values.yaml \
--wait

# > /dev/null 2>&1 & \
# spinner "Installing Spinakker. This will take 1-2 minutes."

# Create a service account
# kubectl create serviceaccount spinnaker-service-account -n spinnaker

# bind new service account to cluster-admin role
# kubectl create clusterrolebinding spinnaker-service-account --clusterrole cluster-admin --serviceaccount=spinnaker:spinnaker-service-account

# Halyard uses the local kubectl to access the cluster. You'll need to configure it to use the newly 
# created service account before deploying Spinnaker. Kubernetes accounts authenticate using usernames 
# and tokens. When a service account is created, Kubernetes makes a new secret and populates it with 
# the account token. To retrieve the token for the spinnaker-service-account, you'll first need to get 
# the name of the secret
TOKEN_SECRET=$(kubectl get serviceaccount -n spinnaker spinnaker-service-account -o jsonpath='{.secrets[0].name}')

# Fetch the contents of the secret into a variable
TOKEN=$(kubectl get secret -n spinnaker $TOKEN_SECRET -o jsonpath='{.data.token}' | base64 --decode)

# Set credentials for service account in kubectl
# kubectl config set-credentials spinnaker-token-user --token $TOKEN

# Set user of current context to newly created spinnaker-token-user by running this command
# kubectl config set-context --current --user spinnaker-token-user

# By setting the current user to spinnaker-token-user, kubectl is now configured to use the 
# spinnaker-service-account, but Halyard does not know anything about that. Add an account 
# to its Kubernetes provider.
# hal config provider kubernetes account add spinnaker-account --provider-version v2

# Because you're deploying Spinnaker to Kubernetes, mark the deployment as 'distributed'.
# hal config deploy edit --type distributed --account-name spinnaker-account

# Spinnaker deployment will be building images, it is necessary to enable artifacts in Spinnaker.
# TODO - really?
# hal config features edit --artifacts true

# K8S_CLUSTER_REGION=$(doctl kubernetes cluster list -o json | grep -Po '"region":.*?[^\\]",'|awk -F':' '{print $2}' | tr -d ' ",')

# echo -e "Spinnaker uses Spaces to store Spinnaker information." \
#         "Currently, DigitalOcean Spaces can only be managed through" \
#         "the DigitalOcean portal UI, there is no way through doctl or" \
#         "the REST API. Before continuing, add a new space to Spaces and" \
#         "copy the name and key of the new space and enter them for the" \
#         "next questions. If you already have a space, then reference the existing one." | fold -s

# echo "Be sure the Space region is the same as the region of your Kubernetes cluster: ${K8S_CLUSTER_REGION}"

# read -p "What is Space name for Spinnaker? " SPACE_NAME
# read -p "What is the access key for the Space named ${SPACE_NAME}? " SPACE_KEY

# SPACES_ENDPOINT="https://${SPACE_NAME}.${K8S_CLUSTER_REGION}.cdn.digitaloceanspaces.com"

# hal config storage s3 edit --access-key-id ${SPACE_KEY} --secret-access-key --endpoint ${SPACES_ENDPOINT_PREFIX} --bucket ${SPACE_NAME} --no-validate

# echo "A space for Spinnaker has been allocated."
# hal config storage edit --type s3

echo -e "\033[32mSpinnaker is available at https://${SPINNAKER_FQDN}\033[39m"
