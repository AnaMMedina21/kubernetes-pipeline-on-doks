#!/bin/bash

BASEDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )")
source "${BASEDIR}/scripts/functions.sh"

# -----------------------------------------------------------------------------
# Install Harbor
# -----------------------------------------------------------------------------
# When installing Harbor, we want to first check if there are existing
# Block Storage Volumes available. If there are, we'll use those, otherwise
# we want to create new volumes for each that are not present. After this
# we'll move on to attaching the volumes to the Kubernetes cluster, followed
# by creating a DNS record if needed, and finally installing Harbor itself. 
# -----------------------------------------------------------------------------

echo "Harbor will now be installed onto the Kubernetes cluster."
echo "This will require a total of five Block Storage Volumes."
echo "Gathering cluster information, please wait..."
echo

# This is a bit cumbersome, but it will ultimately be fairly reliable.
CLUSTER_ID=$(kubectl cluster-info | \
  grep -om 1 "\(https://\)\([^.]\+\)" | \
  awk -F "//" '{print $2}')
CLUSTER_NAME=$(doctl kubernetes cluster get "$CLUSTER_ID" -o text | \
  awk '{if(NR>1)print $2}')
CLUSTER_REGION=$(doctl kubernetes cluster get "$CLUSTER_ID" -o text | \
  awk '{if(NR>1)print $3}')

VOLUMES_NEEDED=("Registry" "Chartmuseum" "Jobservice" "Database" "Redis")
VOLUMES_PRESENT=()
VOLUME_IDS=()
VOLUME_NAME=()
VOLUME_SIZE=()

if ask "Are there existing volumes in DigitalOcean that should be used for Harbor?\033[39m"; then
  echo

  echo "Fetching volume information, please wait..."
  echo

  # Retrieve the list of volumes in DigitalOcean.
  IFS=$'\n'
  VOLUME_LIST=($(doctl compute volume list -o text | awk '{if(NR>1)printf("%s  %-40s  %s %s  %s\n", $1, $2, $3, $4, $5)}'))
  unset IFS

  echo -e "\033[33mOf the following, which volumes are already present in DigitalOcean?\033[39m"
  while true; do
    # Construct the options array, appending an "exit" option to the list.
    VOLUME_PROMPT=()
    for i in "${!VOLUMES_NEEDED[@]}"; do
      VOLUME_PROMPT+=("${VOLUMES_NEEDED[$i]}")
    done
    VOLUME_PROMPT+=("None of the above")

    select_option "${VOLUME_PROMPT[@]}"
    choice=$?

    # If the choice is the last index of the array, break.
    LAST_INDEX=$((${#VOLUME_PROMPT[@]} - 1))
    if [[ "${choice}" -eq "${LAST_INDEX}" ]]; then
      break
    fi

    # Set up the volume 
    SELECTED_VOLUME=$(echo "${VOLUMES_NEEDED[$choice]}" | tr A-Z a-z)
    echo -e "\033[33mWhich of the following volumes should be used for the ${SELECTED_VOLUME} volume?\033[39m"
    select_option "${VOLUME_LIST[@]}"
    choice2=$?

    VOLUME_ID=$(echo ${VOLUME_LIST[$choice2]} | awk '{print $1}')
    VOLUME_NAME=$(echo ${VOLUME_LIST[$choice2]} | awk '{print $2}')
    VOLUME_SIZE=$(echo ${VOLUME_LIST[$choice2]} | awk '{print $3}')

    sed -E 's/\[VOLUME_NAME]/'"${VOLUME_NAME}"'/;s/\[VOLUME_SIZE]/'"${VOLUME_SIZE}Gi"'/;s/\[VOLUME_ID]/'"${VOLUME_ID}"'/;s/\[CLUSTER_ISSUER]/'"${CLUSTER_ISSUER}"'/' \
      "${BASEDIR}"/templates/pvc-harbor-"${SELECTED_VOLUME}".yaml > "${BASEDIR}"/files/pvc-harbor-"${SELECTED_VOLUME}".yaml

    # Add to volumes that are present.
    # These will all have the same index.
    VOLUMES_PRESENT+=("${SELECTED_VOLUME}")
    VOLUME_IDS+=("${VOLUME_ID}")
    VOLUME_NAMES+=("${VOLUME_NAME}")
    VOLUME_SIZES+=("${VOLUME_SIZE}")

    unset VOLUMES_NEEDED[$choice]

    if [[ "${#VOLUMES_NEEDED[@]}" -eq 0 ]]; then
      break
    fi

    # Rebuild VOLUMES_NEEDED array so that the keys are sequential.
    REBUILD_ARRAY=()
    for i in "${!VOLUMES_NEEDED[@]}"; do
      REBUILD_ARRAY+=("${VOLUMES_NEEDED[$i]}")
    done
    VOLUMES_NEEDED=("${REBUILD_ARRAY[@]}")

    echo -e "\033[33mAre the any more volumes that you would like to use?\033[39m"
  done
else
  echo # Spacing.
fi

# If there are volumes still needed, loop through the volumes that are needed and create them.
if [[ "${#VOLUMES_NEEDED[@]}" -gt 0 ]]; then
  echo "Creating the remaining volumes that are needed, please wait..."
fi
for i in "${!VOLUMES_NEEDED[@]}"; do
  SELECTED_VOLUME=$(echo "${VOLUMES_NEEDED[$i]}" | tr A-Z a-z)

  # General volume info.
  VOLUME_NAME="pvc-harbor-${SELECTED_VOLUME}-1"
  if [[ "${SELECTED_VOLUME}" == "registry" || "${SELECTED_VOLUME}" == "chartmuseum" ]]; then
    VOLUME_SIZE="5" # The registry and chartmuseum should be at least 5GB.
  else
    VOLUME_SIZE="1"
  fi

  echo "Creating a ${VOLUME_SIZE}GB Block Storage Volume named ${VOLUME_NAME} in" \
    "the ${CLUSTER_REGION} region. Please wait..."

  CREATE_VOLUME_OUTPUT=$(doctl compute volume create "${VOLUME_NAME}" \
    --region ${CLUSTER_REGION} \
    --fs-type ext4 \
    --size ${VOLUME_SIZE}GiB \
    --output text)

  if [[ $? -eq 0 ]]; then
    echo -e  "\033[32mVolume created.\033[39m"
    
    # Volume ID can only be found after creation.
    VOLUME_ID=$(echo "${CREATE_VOLUME_OUTPUT}" | awk '{if(NR>1)print $1}')

    sed -E 's/\[VOLUME_NAME]/'"${VOLUME_NAME}"'/;s/\[VOLUME_SIZE]/'"${VOLUME_SIZE}Gi"'/;s/\[VOLUME_ID]/'"${VOLUME_ID}"'/' \
      "${BASEDIR}"/templates/pvc-harbor-"${SELECTED_VOLUME}".yaml > "${BASEDIR}"/files/pvc-harbor-"${SELECTED_VOLUME}".yaml

    # Add to volumes that are present.
    # These will all have the same index.
    VOLUMES_PRESENT+=("${SELECTED_VOLUME}")
    VOLUME_IDS+=("${VOLUME_ID}")
    VOLUME_NAMES+=("${VOLUME_NAME}")
    VOLUME_SIZES+=("${VOLUME_SIZE}")
  else
    echo -e "\033[31mThere was a problem creating the ${SELECTED_VOLUME} volume.\033[39m"
    exit 1
  fi
done

echo "Mounting volumes to the Kubernetes cluster..."
# Start with the namespace.
cp "${BASEDIR}"/templates/namespace-harbor.yaml "${BASEDIR}"/files/namespace-harbor.yaml > /dev/null 2>&1
kubectl apply -f "${BASEDIR}"/files/namespace-harbor.yaml > /dev/null 2>&1

for i in "${!VOLUMES_PRESENT[@]}"; do
  kubectl apply -f "${BASEDIR}"/files/pvc-harbor-"${VOLUMES_PRESENT[$i]}".yaml > /dev/null 2>&1

  if [[ $? -eq 0 ]]; then
    echo -e  "\033[Mounted ${VOLUMES_PRESENT[$i]} volume.\033[39m"
  else
    echo -e "\033[31mThere was a problem mounting the ${VOLUMES_PRESENT[$i]} volume.\033[39m"
    exit 1
  fi
done
echo

# Staging or Production
echo -e "\033[33mFollow fair use policies by only choosing Production if you are ready to go live with Jenkins. What cluster issuer type do you want to use?\033[39m" | fold -s
CLUSTER_ISSUERS=("letsencrypt-staging" "letsencrypt-prod")
select_option "${CLUSTER_ISSUERS[@]}"
choice=$?
CLUSTER_ISSUER="${CLUSTER_ISSUERS[$choice]}"
echo

# Ask for fully qualified domain name
echo
echo -en "\033[33mWhat is the FQDN that Harbor will be hosted from?\033[39m "
echo -e "Example: https://harbor.rootdomain.com, assuming *.rootdomain.com is the DNS A record."
read -p "Harbor domain name: https://" HARBOR_FQDN
# Strip out 'http://' and 'https://'.
HARBOR_FQDN=$(echo "${HARBOR_FQDN}" | sed -e 's/http[s]\{0,1\}:\/\///g')

echo

# Configure Harbor values.
echo "Configuring Harbor..."

# The initial password of Harbor admin.
ADMIN_PASSWORD=$(head /dev/urandom | LC_ALL=C tr -dc A-Za-z0-9 | head -c 75)
# The secret key used for encryption. Must be a string of 16 chars.
SECRET_KEY=$(head /dev/urandom | LC_ALL=C tr -dc A-Za-z0-9 | head -c 16)

SED_STRING=""
SED_STRING+="s/\[ADMIN_PASSWORD]/${ADMIN_PASSWORD}/;"
SED_STRING+="s/\[SECRET_KEY]/${SECRET_KEY}/;"
SED_STRING+="s/\[EXTERNAL_URL]/${HARBOR_FQDN}/;"
SED_STRING+="s/\[CORE_URL]/${HARBOR_FQDN}/;"
SED_STRING+="s/\[NOTARY_URL]/notary.${HARBOR_FQDN}/;"
SED_STRING+="s/\[CLUSTER_ISSUER]/${CLUSTER_ISSUER}/;"

# Configure all of the volume information for Harbor.
for i in "${!VOLUMES_PRESENT[@]}"; do
    SELECTED_VOLUME=$(echo "${VOLUMES_PRESENT[$i]}" | tr a-z A-Z)

    SED_STRING+="s/\[PVC_HARBOR_${SELECTED_VOLUME}_NAME]/${VOLUME_NAMES[$i]}/;"
    SED_STRING+="s/\[PVC_HARBOR_${SELECTED_VOLUME}_SIZE]/${VOLUME_SIZES[$i]}/;"
done

sed -E "${SED_STRING}" "${BASEDIR}"/templates/harbor-values.yaml > "${BASEDIR}"/files/harbor-values.yaml

# Install Harbor
# Since Harbor needs to be installed via a local chart, clone the chart to the
# local machine, and then checkout version 1.0.1.
if [[ ! -d "${BASEDIR}"/files/harbor-helm ]]; then
  git clone https://github.com/goharbor/harbor-helm "${BASEDIR}"/files/harbor-helm > /dev/null 2>&1
fi
git --git-dir="${BASEDIR}"/files/harbor-helm/.git --work-tree="${BASEDIR}"/files/harbor-helm checkout 1.0.1 > /dev/null 2>&1

helm upgrade --install harbor --namespace harbor \
  "${BASEDIR}"/files/harbor-helm --values \
  "${BASEDIR}"/files/harbor-values.yaml > /dev/null 2>&1 & \
spinner "Installing Harbor onto the Kubernetes cluster"

kubectl create secret docker-registry regcred -n default --docker-server="${HARBOR_FQDN}" --docker-username=admin --docker-password=${ADMIN_PASSWORD}
kubectl create secret docker-registry regcred -n harbor  --docker-server="${HARBOR_FQDN}" --docker-username=admin --docker-password=${ADMIN_PASSWORD}

echo -e "\033[32mHarbor is available at via https://${HARBOR_FQDN}\033[39m"
echo -e "\033[33mLog in using the username\033[39m: admin"
echo -e "\033[33mand the password\033[39m: ${ADMIN_PASSWORD}"
