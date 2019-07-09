#!/bin/bash

#One of the problems that this script runs into is that Sonarqube doesn't have a way to reset the default admin password 
#upon installation. We have to use a curl command and the Sonarqube API. This script gives the installer the option to run
#their instance of Sonarqube in either a production or staging environment. If they choose production, this script will 
#stand up Sonarqube on the FQDN, wait for the url to return a 200 status code, and change the admin password via a curl command.
#If however, they choose staging, this script will call a port-forward command to serve the Sonarqube dashboard on the localhost
#and then it will call the Sonarqube api via the localhost as opposed to the FQDN which is not directly accessible. The following
#function allows this script to perform the same setup for both production and staging environments based on the argument passed to
#the function.

sonarqube_setup(){
  echo "Generating a Sonarqube Access Token for the admin account"
  ADMIN_TOKEN=$(curl -X POST --silent -u admin:admin "$1/api/user_tokens/generate?name=sonarqube_admin_test" | jq -r '.token')

  kubectl delete secret sonarqube-admin --namespace sonarqube >  /dev/null 2>&1 #in case the secrets don't exist 
  kubectl delete secret sonarqube-admin --namespace kube-system > /dev/null 2>&1
  kubectl delete configmap sonarqube-host-url --namespace sonarqube > /dev/null 2>&1

  echo "Storing token as secret in Kubernetes"
  kubectl create secret generic sonarqube-admin --from-literal=SONARQUBE_ADMIN_PASSWORD="${ADMIN_PASSWORD}" --from-literal=SONARQUBE_ADMIN_TOKEN="${ADMIN_TOKEN}" --namespace kube-system
  kubectl annotate secret sonarqube-admin --namespace kube-system replicator.v1.mittwald.de/replication-allowed='true' replicator.v1.mittwald.de/replication-allowed-namespaces='sonarqube'

  echo "Replicating secret across namespaces"
  kubectl create secret generic sonarqube-admin --namespace sonarqube
  kubectl annotate secret sonarqube-admin --namespace sonarqube replicator.v1.mittwald.de/replicate-from=kube-system/sonarqube-admin

  echo "Creating a configmap in Kubernetes to store the Sonarqube Host URl"
  Create a configMap to store the host url for Sonarqube in the sonarqube namespace
  kubectl create configmap sonarqube-host-url --from-literal=sonarqube.host.url="https://${SONARQUBE_FQDN}" --namespace sonarqube 
  kubectl annotate configmap sonarqube-host-url --namespace sonarqube replicator.v1.mittwald.de/replication-allowed='true' replicator.v1.mittwald.de/replication-allowed-namespaces='jenkins'

  # Change the admin password using the Sonarqube web api and a curl command
  echo "Setting the admin password"
  curl -X POST -u admin:admin "$1/api/users/change_password?login=admin&password=${ADMIN_PASSWORD}&previousPassword=admin"
}

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
read -p "Sonarqube domain name: https://" SONARQUBE_FQDN

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

# Set the admin password to a complex string of length 75
ADMIN_PASSWORD=$(head /dev/urandom | LC_ALL=C tr -dc A-Za-z0-9 | head -c 75)

# Configure Sonarqube values
echo "Configuring Sonarqube. This will take 2-3 minutes."
sed -E 's/\[HOSTNAME]/'"${SONARQUBE_FQDN}"'/;s/\[CLUSTER_ISSUER]/'"${CLUSTER_ISSUER}"'/' \
  "${BASEDIR}"/templates/sonarqube-values.yaml > "${BASEDIR}"/files/sonarqube-values.yaml

# Install Sonarqube
helm upgrade --install sonarqube stable/sonarqube --wait --namespace sonarqube --values "${BASEDIR}"/files/sonarqube-values.yaml > /dev/null & \
spinner "Installing Sonarqube onto Kubernetes cluster"

#If we try to make a curl request against the sonarqube domain with a staging cluster issuer we will get an error because 
#the Sonarqube dashboard is only accessible via a port forward 
#Because of this, we have separated the two choices with an if statment. 
if [ $CLUSTER_ISSUER == "letsencrypt-prod" ]; then

  echo "Waiting for ${SONARQUBE_FQDN} to be up and running"

  #Get the http status code from the sonarqube domain name and store it in a variable.
  server_status=$(curl -s -o /dev/null -w "%{http_code}" https://${SONARQUBE_FQDN})
  #Check to see if the status code is 200.
  while [ $server_status -ne 200 ]
  do
    #If it isn't, wait three seconds and check it again.
    sleep 10
    server_status=$(curl -s -o /dev/null -w "%{http_code}" https://${SONARQUBE_FQDN})
  done 
  #Call the function to setup sonarqube with a FQDN as the argument
  sonarqube_setup() "https://${SONARQUBE_FQDN}"

#The user chooses the staging option
elif [ $CLUSTER_ISSUER == "letsencrypt-staging" ]; then

  # Get local access the sonarqube dashboard via a port forward command
  kubectl port-forward service/sonarqube-sonarqube -n sonarqube 9000:9000 &
  #Store the process id of the port forward call in a var
  pid=$!
  echo "Waiting for localhost:9000 to be up and running"
  sleep 10
  #Call the function to setup sonarqube with local host as the argument
  sonarqube_setup "localhost:9000"
  #End the process
  kill $pid
 
fi 

  echo -e "\033[32mSonarqube is available at via https://${SONARQUBE_FQDN}\033[39m"
  echo -e "\033[33mLog in using the username\033[39m: admin"
  echo -e "\033[33mand the password\033[39m: ${ADMIN_PASSWORD}"

