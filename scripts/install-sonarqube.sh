#!/bin/bash

BASEDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )")
source "${BASEDIR}/scripts/functions.sh"

# -----------------------------------------------------------------------------
# Install Sonarqube
# -----------------------------------------------------------------------------
# When installing Sonarqube, we want to first check if there is an existing
# Block Storage Volume available. If there is, we'll use that, otherwise
# we want to create a new volume. Once the volume is present, we can move
# on to setting up the PV/PVC for Sonarqube, and finally installing the
# Sonarqube instance itself on the Kubernetes cluster.
# -----------------------------------------------------------------------------

echo "Sonarqube will now be installed onto the Kubernetes cluster."
echo

# TODO:
#   Check for existing volume
#   Retrieve the list of volumes in DigitalOcean.

# Ask for fully qualified domain name
echo
echo -en "\033[33mWhat is the FQDN that Sonarqube will be hosted from?\033[39m "
echo -e "Example: https://sonarqube.rootdomain.com, assuming *.rootdomain.com is the DNS A record."
read -p "Jenkins domain name: https://" SONARQUBE_FQDN

# Strip out 'http://' and 'https://'.
SONARQUBE_FQDN=$(echo "${SONARQUBE_FQDN}" | sed -e 's/http[s]\{0,1\}:\/\///g')
echo

# Staging or Production
echo -e "\033[33mFollow fair use policies by only choosing Production if you are ready to go live with Sonarqube. What cluster issuer type do you want to use?\033[39m" | fold -s
CLUSTER_ISSUERS=("letsencrypt-staging" "letsencrypt-prod")
select_option "${CLUSTER_ISSUERS[@]}"
choice=$?
CLUSTER_ISSUER="${CLUSTER_ISSUERS[$choice]}"
echo

# The initial password of Sonarqube admin.
ADMIN_PASSWORD=$(head /dev/urandom | LC_ALL=C tr -dc A-Za-z0-9 | head -c 75)

kubectl delete secret sonarqube --namespace kube-system
kubectl create secret generic sonarqube --from-literal=SONARQUBE_ADMIN_PASSWORD="${ADMIN_PASSWORD}" --namespace kube-system
kubectl annotate secret sonarqube --namespace kube-system replicator.v1.mittwald.de/replication-allowed='true' replicator.v1.mittwald.de/replication-allowed-namespaces='sonarqube'

# Configure Sonarqube values
echo "Configuring Sonarqube. This will take 2-3 minutes."
sed -E 's/\[HOSTNAME]/'"${SONARQUBE_FQDN}"'/;s/\[CLUSTER_ISSUER]/'"${CLUSTER_ISSUER}"'/' \
  "${BASEDIR}"/templates/sonarqube-values.yaml > "${BASEDIR}"/files/sonarqube-values.yaml

# Install Sonarqube
helm upgrade --install sonarqube stable/sonarqube --wait --namespace sonarqube --values "${BASEDIR}"/files/sonarqube-values.yaml > /dev/null & \
spinner "Installing Sonarqube onto Kubernetes cluster"

#This should be more dynamic than just waiting for two minutes. However, we do need to wait, because if we don't the curl command below won't be able to execute.  
#Ideally we put a loop of some kind in here that checks if the website is running and every n seconds and then once it returns a certain code, the loop breaks.
#For now this will suffice.
echo "Waiting for ${SONARQUBE_FQDN} to be up and running."
sleep 120 

# Change the admin password using the Sonarqube web api and a curl command
echo "Setting the admin password"
curl -X POST -u admin:admin "https://${SONARQUBE_FQDN}/api/users/change_password?login=admin&password=${ADMIN_PASSWORD}&previousPassword=admin"

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    *)          machine="UNKNOWN:${unameOut}"
esac

# Copy token to the administrator's operating system clipboard
if [ $machine == "Mac" ]; then
  echo $ADMIN_PASSWORD | pbcopy
elif [ $machine == "Linux" ]; then
  echo $ADMIN_PASSWORD | xclip -selection clipboard -i
elif [ $machine == "Cygwin" ]; then
  echo $ADMIN_PASSWORD > /dev/clipboard
fi

echo "Sonarqube admin password is now in your $machine clipboard."
echo 
echo "Sonarqube sucessfully installed."
