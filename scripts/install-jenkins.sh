#!/bin/bash

BASEDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )")
source "${BASEDIR}/scripts/functions.sh"
NOTES="${BASEDIR}/files/install-notes.md"

# -----------------------------------------------------------------------------
# Install Jenkins
# -----------------------------------------------------------------------------
# When installing Jenkins, we want to first check if there is an existing
# Block Storage Volume available. If there is, we'll use that, otherwise
# we want to create a new volume. Once the volume is present, we can move
# on to setting up the PV/PVC for Jenkins, and finally installing the
# Jenkins instance itself on the Kubernetes cluster.
# -----------------------------------------------------------------------------

echo "Jenkins will now be installed onto the Kubernetes cluster."
echo

# Check for existing volume
if ask "Use existing Block Storage Volume for Jenkins?"; then
  echo
  echo -e "\033[33mWhich volume will be used for Jenkins?\033[39m"

  # Retrieve the list of volumes in DigitalOcean.
  IFS=$'\n'
  VOLUME_LIST=($(doctl compute volume list -o text | awk '{if(NR>1)printf("%s  %-40s  %s %s  %s\n", $1, $2, $3, $4, $5)}'))
  unset IFS

  select_option "${VOLUME_LIST[@]}"
  choice=$?

  VOLUME_ID=$(echo ${VOLUME_LIST[$choice]} | awk '{print $1}')
  VOLUME_NAME=$(echo ${VOLUME_LIST[$choice]} | awk '{print $2}')
  VOLUME_SIZE=$(echo ${VOLUME_LIST[$choice]} | awk '{print $3}')
else # No existing volume is being used.
  echo

  # Create new volume in DigitalOcean
  echo "Gathering cluster information..."
  
  # General volume info.
  VOLUME_NAME="pvc-jenkins"
  VOLUME_SIZE="5" # In gigabytes.

  # This is a bit cumbersome, but it will ultimately be fairly reliable.
  CLUSTER_ID=$(kubectl cluster-info | \
    grep -om 1 "\(https://\)\([^.]\+\)" | \
    awk -F "//" '{print $2}')
  CLUSTER_NAME=$(doctl kubernetes cluster get "${CLUSTER_ID}" -o text | \
    awk '{if(NR>1)print $2}')
  CLUSTER_REGION=$(doctl kubernetes cluster get "${CLUSTER_ID}" -o text | \
    awk '{if(NR>1)print $3}')

  echo "Creating a ${VOLUME_SIZE}GB Block Storage Volume named ${VOLUME_NAME} in" \
    "the ${CLUSTER_REGION} region..."

  CREATE_VOLUME_OUTPUT=$(doctl compute volume create "${VOLUME_NAME}" \
	  --region ${CLUSTER_REGION} \
  	--fs-type ext4 \
	  --size ${VOLUME_SIZE}GiB \
    --output text)

  if [[ $? -eq 0 ]]; then
    echo -e  "\033[32mVolume created.\033[39m"
  else
    echo -e "\033[31mThere was a problem creating the volume.\033[39m"
    exit 1
  fi

  # Volume ID can only be found after creation.
  VOLUME_ID=$(echo "${CREATE_VOLUME_OUTPUT}" | awk '{if(NR>1)print $1}')
fi;

# Create the PV/PVC
echo "Attaching volume ${VOLUME_NAME} to the Kubernetes cluster..."

# Set all of the values for the new/existing DigitalOcean Volume and apply the config.
sed -E 's/\[VOLUME_NAME]/'"${VOLUME_NAME}"'/;s/\[VOLUME_SIZE]/'"${VOLUME_SIZE}Gi"'/;s/\[VOLUME_ID]/'"${VOLUME_ID}"'/' \
  "${BASEDIR}"/templates/pvc-jenkins.yaml > "${BASEDIR}"/files/pvc-jenkins.yaml
kubectl apply -f "${BASEDIR}"/files/pvc-jenkins.yaml > /dev/null

if [[ $? -eq 0 ]]; then
  echo -e "\033[32mVolume attached to Kubernetes.\033[39m"
else
  echo -e "\033[31mThere was a problem attaching the volume.\033[39m"
fi
echo

# Ask for fully qualified domain name
echo
echo -en "\033[33mWhat is the FQDN that Jenkins will be hosted from?\033[39m "
echo -e "Example: https://jenkins.rootdomain.com, assuming *.rootdomain.com is the DNS A record."
read -p "Jenkins domain name: https://" JENKINS_FQDN
# Strip out 'http://' and 'https://'.
JENKINS_FQDN=$(echo "${JENKINS_FQDN}" | sed -e 's/http[s]\{0,1\}:\/\///g')
echo

# Staging or Production
echo -e "\033[33mFollow fair use policies by only choosing Production if you are ready to go live with Jenkins. What cluster issuer type do you want to use?\033[39m" | fold -s
CLUSTER_ISSUERS=("letsencrypt-staging" "letsencrypt-prod")
select_option "${CLUSTER_ISSUERS[@]}"
choice=$?
CLUSTER_ISSUER="${CLUSTER_ISSUERS[$choice]}"
echo

# Configure Jenkins values
echo "Configuring Jenkins. This will take 2-3 minutes."
sed -E 's/\[HOSTNAME]/'"${JENKINS_FQDN}"'/;s/\[PVC_NAME]/'"${VOLUME_NAME}"'/;s/\[CLUSTER_ISSUER]/'"${CLUSTER_ISSUER}"'/' \
  "${BASEDIR}"/templates/jenkins-values.yaml > "${BASEDIR}"/files/jenkins-values.yaml

# Install Jenkins
helm upgrade --install jenkins --wait --namespace jenkins stable/jenkins --values "${BASEDIR}"/files/jenkins-values.yaml > /dev/null & \
spinner "Installing Jenkins onto Kubernetes cluster"

# Pods can only reference secrets in same namespaces. Copy the Harbor registry secret for Kaniki pushing.
kubectl get secret regcred -n harbor -o yaml | sed "s/namespace: harbor/namespace: jenkins/" | kubectl create -n jenkins -f -

echo -e "\033[32mJenkins is available at https://${JENKINS_FQDN}\033[39m"
JENKINS_PASSWORD=$(printf $(kubectl get secret --namespace jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo)
echo -e "\033[33mLog in using the username\033[39m: admin"
echo -e "\033[33mand the password\033[39m: ${JENKINS_PASSWORD}"